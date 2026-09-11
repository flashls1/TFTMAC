import { execFileSync } from 'node:child_process';

const [port, service] = process.argv.slice(2);
let account = '';
let password = '';
let socket;
let helperStage = 'arguments';

function readPrivateStdin() {
  return new Promise((resolve, reject) => {
    let data = '';
    process.stdin.setEncoding('utf8');
    process.stdin.on('data', (chunk) => { data += chunk; });
    process.stdin.on('end', () => resolve(data));
    process.stdin.on('error', reject);
  });
}

function fail(message) {
  console.error(`TFT_LOGIN_HELPER_STAGE=${helperStage}`);
  console.error(message);
  process.exitCode = 1;
}

try {
  if (!/^\d+$/.test(port || '') || !service) {
    throw new Error('Invalid local helper arguments');
  }

  helperStage = 'target_list';
  let targetListJson = '';
  let targetListError;
  for (let attempt = 1; attempt <= 6; attempt += 1) {
    try {
      targetListJson = execFileSync('/usr/bin/curl', [
        '--silent',
        '--show-error',
        '--fail',
        '--noproxy',
        '*',
        '--connect-timeout',
        '2',
        '--max-time',
        '5',
        `http://127.0.0.1:${port}/json/list`
      ], {
        encoding: 'utf8',
        stdio: ['ignore', 'pipe', 'ignore'],
        timeout: 7000,
        maxBuffer: 1024 * 1024
      });
      if (targetListJson.trim()) break;
    } catch (error) {
      targetListError = error;
    }
    await new Promise((resolve) => setTimeout(resolve, attempt * 500));
  }
  if (!targetListJson.trim()) {
    throw targetListError || new Error('Empty WebView target list');
  }
  const targets = JSON.parse(targetListJson);
  helperStage = 'target_select';
  const target = targets.find((candidate) => candidate.type === 'page' && candidate.webSocketDebuggerUrl)
    || targets.find((candidate) => candidate.webSocketDebuggerUrl);
  if (!target) throw new Error('No debuggable WebView target');

  helperStage = 'websocket_connect';
  socket = new WebSocket(target.webSocketDebuggerUrl);
  const pending = new Map();
  let nextId = 1;

  await new Promise((resolve, reject) => {
    const timeout = setTimeout(() => reject(new Error('WebView connection timeout')), 5000);
    socket.addEventListener('open', () => {
      clearTimeout(timeout);
      resolve();
    }, { once: true });
    socket.addEventListener('error', reject, { once: true });
  });

  socket.addEventListener('message', (event) => {
    const message = JSON.parse(event.data);
    const waiter = pending.get(message.id);
    if (!waiter) return;
    pending.delete(message.id);
    if (message.error) waiter.reject(new Error(message.error.message));
    else waiter.resolve(message.result);
  });

  function call(method, params = {}) {
    const id = nextId++;
    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => {
        pending.delete(id);
        reject(new Error('WebView command timeout'));
      }, 5000);
      pending.set(id, {
        resolve: (result) => {
          clearTimeout(timeout);
          resolve(result);
        },
        reject: (error) => {
          clearTimeout(timeout);
          reject(error);
        }
      });
      socket.send(JSON.stringify({ id, method, params }));
    });
  }

  helperStage = 'runtime_enable';
  await call('Runtime.enable');
  helperStage = 'form_preflight';
  let preflightResult;
  for (let attempt = 1; attempt <= 8; attempt += 1) {
    const preflight = await call('Runtime.evaluate', {
      expression: `(() => {
        const username = document.querySelector('input[name="username"]');
        const password = document.querySelector('input[name="password"]');
        const captcha = Array.from(document.querySelectorAll(
          'iframe[src*="captcha" i], [data-sitekey], [class*="captcha" i]'
        ));
        const visibleCaptcha = captcha.some((element) => {
          const rect = element.getBoundingClientRect();
          const style = getComputedStyle(element);
          return rect.width > 0 && rect.height > 0 && style.display !== 'none' &&
            style.visibility !== 'hidden' && Number(style.opacity || 1) !== 0;
        });
        return { fieldsReady: Boolean(username && password), visibleCaptcha };
      })()`,
      returnByValue: true
    });
    preflightResult = preflight.result?.value;
    if (preflightResult?.fieldsReady || preflightResult?.visibleCaptcha) break;
    await new Promise((resolve) => setTimeout(resolve, attempt * 250));
  }

  if (!preflightResult?.fieldsReady) {
    fail('Official Riot login fields were not found; credentials were not read.');
  } else if (preflightResult.visibleCaptcha) {
    fail('A CAPTCHA is visible on the Riot login form; the helper stopped without reading credentials.');
  } else {
    if (service !== '--stdin') throw new Error('The DEV WebView helper accepts only its private local credential pipe');
    helperStage = 'private_credential_pipe';
    const payload = JSON.parse(await readPrivateStdin());
    account = typeof payload.username === 'string' ? payload.username : '';
    password = typeof payload.password === 'string' ? payload.password : '';
    if (!account || !password) throw new Error('Empty local credential payload');

    const expression = `(async () => {
      const username = document.querySelector('input[name="username"]');
      const password = document.querySelector('input[name="password"]');
      if (!username || !password) return { status: 'fields_missing' };

      const setValue = (element, value) => {
        const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
        element.focus();
        setter.call(element, value);
        element.dispatchEvent(new InputEvent('input', {
          bubbles: true,
          composed: true,
          inputType: 'insertText',
          data: null
        }));
        element.dispatchEvent(new Event('change', { bubbles: true, composed: true }));
        element.blur();
      };

      setValue(username, ${JSON.stringify(account)});
      setValue(password, ${JSON.stringify(password)});
      await new Promise((resolve) => setTimeout(resolve, 500));

      const root = password.form || document;
      const submit = Array.from(root.querySelectorAll('button[type="submit"]'))
        .filter((element) => {
          const rect = element.getBoundingClientRect();
          return rect.width > 0 && rect.height > 0;
        })
        .sort((left, right) => (
          right.getBoundingClientRect().left - left.getBoundingClientRect().left
        ))[0];
      if (!submit) return { status: 'submit_missing' };
      if (submit.disabled || submit.getAttribute('aria-disabled') === 'true') {
        return { status: 'submit_disabled' };
      }

      submit.click();
      return { status: 'clicked' };
    })()`;

    helperStage = 'form_submit';
    const result = await call('Runtime.evaluate', {
      expression,
      returnByValue: true,
      awaitPromise: true
    });
    if (result.result?.value?.status !== 'clicked') {
      fail('The Riot login form did not activate Sign In; credentials were not printed.');
    } else {
      console.log('The official Riot login form was submitted through standard DOM events; credentials were not printed.');
    }
  }
} catch {
  fail(`The Riot WebView login helper failed without printing credentials (stage: ${helperStage}).`);
} finally {
  account = '';
  password = '';
  socket?.close();
}
