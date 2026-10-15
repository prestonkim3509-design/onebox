// OneBox starter.
//
// This folder sits inside the standard, unmodified Electron program, which Windows
// Smart App Control already trusts. All of OneBox itself lives in code files at
// %LOCALAPPDATA%\OneBox\versions\onebox-<version>.asar. The starter loads the newest
// one. If a version fails to load, it is set aside and the one before it runs.

const { app, dialog, shell } = require('electron');
const path = require('path');
const ofs = require('original-fs');

app.setName('OneBox');                          // settings stay in %APPDATA%\OneBox
if (process.platform === 'win32') app.setAppUserModelId('com.onebox.app');

const root = process.env.ONEBOX_HOME ||
  path.join(process.env.LOCALAPPDATA || app.getPath('appData'), 'OneBox');
const versionsDir = path.join(root, 'versions');

function cmp(a, b) {
  const x = a.split('.').map(Number), y = b.split('.').map(Number);
  for (let i = 0; i < 3; i++) { const d = (x[i] || 0) - (y[i] || 0); if (d) return d; }
  return 0;
}

function versions() {
  try {
    return ofs.readdirSync(versionsDir)
      .map(f => (/^onebox-(\d+\.\d+\.\d+)\.asar$/.exec(f) || [])[1])
      .filter(Boolean)
      .sort(cmp)
      .reverse();
  } catch (e) { return []; }
}

let started = false;
for (const v of versions()) {
  const file = path.join(versionsDir, 'onebox-' + v + '.asar');
  try {
    global.ONEBOX_CORE = { version: v, path: file, versionsDir, root, iconPath: path.join(__dirname, 'icon.png') };
    require(path.join(file, 'main.js'));
    console.log('[OneBox] running version ' + v);
    started = true;
    break;
  } catch (err) {
    console.error('[OneBox] version ' + v + ' did not load:', err);
    try { ofs.renameSync(file, file + '.bad'); } catch (e) {}
  }
}

if (!started) {
  app.whenReady().then(async () => {
    const r = await dialog.showMessageBox({
      type: 'error',
      title: 'OneBox',
      message: 'OneBox needs to finish installing.',
      detail: 'Run the OneBox install line in PowerShell again. Your saved lives and settings are kept.',
      buttons: ['Open install page', 'Close']
    });
    if (r.response === 0) await shell.openExternal('https://github.com/prestonkim3509-design/onebox');
    app.quit();
  });
}
