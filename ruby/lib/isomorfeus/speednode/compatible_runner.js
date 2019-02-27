var vm = require('vm');
const net = require('net');
var contexts = {};
var process_exit = false;

/*
 * Versions of node before 0.12 (notably 0.10) didn't properly propagate
 * syntax errors.
 * This also regressed in the node 4.0 releases.
 *
 * To get around this, if it looks like we are missing the location of the
 * error, we guess it is (execjs):1
 *
 * This is obviously not ideal, but only affects syntax errors, and only on
 * these versions.
 */
function massageStackTrace(stack) {
  if (stack && stack.indexOf("SyntaxError") == 0) {
    return "(execjs):1\n" + stack;
  } else {
    return stack;
  }
}

function getContext(uuid) {
  return contexts[uuid] || (contexts[uuid] = vm.createContext())
}

var commands = {
  deleteContext: function(uuid) {
    delete contexts[uuid];
    return [1];
  },
  exit: function(code) {
    process_exit = code;
    return ['ok'];
  },
  exec: function execJS(input) {
    var context = getContext(input.context);
    var source = input.source;
    try {
      var program = function(){
        return vm.runInContext(source, context, "(execjs)");
      }
      var result = program();
      if (typeof result == 'undefined' && result !== null) {
        return ['ok'];
      } else {
        try {
          return ['ok', result];
        } catch (err) {
          return ['err', '' + err, err.stack];
        }
      }
    } catch (err) {
      return ['err', '' + err, massageStackTrace(err.stack)];
    }
  }
}

var server = net.createServer(function(s) {
  var received_data = '';

  s.on('data', function (data) {
    received_data += data;

    if (received_data[received_data.length - 1] !== "\n") { return; }

    var request = received_data;
    received_data = '';

    var input = JSON.parse(request);
    var result = commands[input.cmd].apply(null, input.args);
    var outputJSON = '';

    try {
      outputJSON = JSON.stringify(result);
    } catch(err) {
      outputJSON = JSON.stringify(['err', '' + err, err.stack]);
    }
    s.write(outputJSON + '\n');
    if (process_exit) { process.exit(process_exit); }
  });
});

var socket_path = process.env.SOCKET_PATH;
if (!socket_path) { throw 'No SOCKET_PATH given!'; };
server.listen(socket_path);
