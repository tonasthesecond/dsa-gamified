// Hosts one compiled submission for one battle: node host.js <classes.js>.
//
// Reads one request per line on stdin, "start" or "decide<TAB><state JSON>",
// calls the TeaVM main once per request, and writes one JSON object per line
// on stdout: {"console":...} followed by Runner's reply fields, or Runner's
// {"internal":...} as it is. Everything the student prints is captured here,
// through TeaVM's stdout hooks, so nothing the student prints can reach stdout
// and pass for a reply.
//
// Not a .java file, so Server.copySources never copies it into a build.

const crypto = require('crypto');

const MAX_OUTPUT_BYTES = 2000000; // over the whole battle
const MAX_CONSOLE_CHARS = 4000; // per reply

let captured = [];
let totalOutput = 0;
/** The request being served, so a failure reply has the fields its kind of reply has. */
let op = null;

function capture(msg) {
  totalOutput += msg.length;
  if (totalOutput > MAX_OUTPUT_BYTES) {
    // Sent from inside the print, because a student printing in a loop never
    // gives control back. The process is done after this.
    reply(failure('output_limit', 'printed more than ' + MAX_OUTPUT_BYTES + ' characters'));
    process.exit(0);
  }
  captured.push(msg);
}
// Must be set before the require: TeaVM reads them when the module loads.
globalThis.$rt_putStdoutCustom = capture;
globalThis.$rt_putStderrCustom = capture;

const program = require(process.argv[2]);

function consoleText(text) {
  return text.length <= MAX_CONSOLE_CHARS
    ? text
    : text.substring(0, MAX_CONSOLE_CHARS) + '\n... [output truncated]';
}

/** fields is an object, or a JSON object string from Runner. */
function reply(fields) {
  if (typeof fields === 'string' && fields.startsWith('{"internal":')) {
    // Not the student's doing, so it goes back as is, without their output.
    captured = [];
    process.stdout.write(fields + '\n');
    return;
  }
  const head = '{"console":' + JSON.stringify(consoleText(captured.join('')));
  const body = typeof fields === 'string' ? fields : JSON.stringify(fields);
  captured = [];
  process.stdout.write(body === '{}' ? head + '}\n' : head + ',' + body.substring(1) + '\n');
}

/** A decide reply always has "action", a start reply never does, as in Runner. */
function failure(kind, message) {
  const error = { kind, message };
  return op === 'decide' ? { action: null, error } : { error };
}

function crashed(err) {
  reply(failure('crashed', String(err && err.message || err)));
  process.exit(0);
}

const queue = [];
let busy = false;

require('readline').createInterface({ input: process.stdin }).on('line', line => {
  queue.push(line);
  pump();
});

function pump() {
  if (busy || queue.length === 0) return;
  busy = true;
  const line = queue.shift();
  const tab = line.indexOf('\t');
  const args = tab < 0 ? [line] : [line.substring(0, tab), line.substring(tab + 1)];
  op = args[0];
  const nonce = crypto.randomBytes(16).toString('hex');
  captured = [];
  try {
    program.main([nonce, ...args], err => {
      if (err) return crashed(err);
      finish(nonce);
    });
  } catch (err) {
    crashed(err);
  }
}

function finish(nonce) {
  const text = captured.join('');
  const at = text.lastIndexOf(nonce);
  if (at < 0) return crashed('the runner printed no reply');
  const end = text.indexOf('\n', at);
  captured = [text.substring(0, at) + (end < 0 ? '' : text.substring(end + 1))];
  reply(text.substring(at + nonce.length, end < 0 ? text.length : end));
  busy = false;
  pump();
}
