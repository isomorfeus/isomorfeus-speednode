'use strict';

const vm = require('vm');
const net = require('net');
const os = require('os');
let contexts = {};
let process_exit = false;

/*** circular-json, originally taken from https://raw.githubusercontent.com/WebReflection/circular-json/
 Copyright (C) 2013-2017 by Andrea Giammarchi - @WebReflection

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.

 ***

 the original version has been restructured and modified to fit in here,
 only stringify is used, unused parts removed.

 */

const CircularJSON = {};
CircularJSON.specialChar = '~';
CircularJSON.safeSpecialChar =  '\\x' + ('0' + CircularJSON.specialChar.charCodeAt(0).toString(16)).slice(-2);
CircularJSON.escapedSafeSpecialChar = '\\' + CircularJSON.safeSpecialChar;
CircularJSON.specialCharRG = new RegExp(CircularJSON.safeSpecialChar, 'g');
CircularJSON.indexOf = [].indexOf || function(v){
    for(let i=this.length;i--&&this[i]!==v;);
    return i;
  };

CircularJSON.generateReplacer = function (value, replacer, resolve) {
    let
        doNotIgnore = false,
        inspect = !!replacer,
        path = [],
        all  = [value],
        seen = [value],
        mapp = [resolve ? CircularJSON.specialChar : '[Circular]'],
        last = value,
        lvl  = 1,
        i, fn
    ;
    if (inspect) {
      fn = typeof replacer === 'object' ?
          function (key, value) {
            return key !== '' && CircularJSON.indexOf.call(replacer, key) < 0 ? void 0 : value;
          } :
          replacer;
    }
    return function(key, value) {
      // the replacer has rights to decide
      // if a new object should be returned
      // or if there's some key to drop
      // let's call it here rather than "too late"
      if (inspect) value = fn.call(this, key, value);

      // first pass should be ignored, since it's just the initial object
      if (doNotIgnore) {
        if (last !== this) {
          i = lvl - CircularJSON.indexOf.call(all, this) - 1;
          lvl -= i;
          all.splice(lvl, all.length);
          path.splice(lvl - 1, path.length);
          last = this;
        }
        // console.log(lvl, key, path);
        if (typeof value === 'object' && value) {
          // if object isn't referring to parent object, add to the
          // object path stack. Otherwise it is already there.
          if (CircularJSON.indexOf.call(all, value) < 0) {
            all.push(last = value);
          }
          lvl = all.length;
          i = CircularJSON.indexOf.call(seen, value);
          if (i < 0) {
            i = seen.push(value) - 1;
            if (resolve) {
              // key cannot contain specialChar but could be not a string
              path.push(('' + key).replace(CircularJSON.specialCharRG, CircularJSON.safeSpecialChar));
              mapp[i] = CircularJSON.specialChar + path.join(CircularJSON.specialChar);
            } else {
              mapp[i] = mapp[0];
            }
          } else {
            value = mapp[i];
          }
        } else {
          if (typeof value === 'string' && resolve) {
            // ensure no special char involved on deserialization
            // in this case only first char is important
            // no need to replace all value (better performance)
            value = value
                .replace(CircularJSON.safeSpecialChar, CircularJSON.escapedSafeSpecialChar)
                .replace(CircularJSON.specialChar, CircularJSON.safeSpecialChar);
          }
        }
      } else {
        doNotIgnore = true;
      }
      return value;
    };
  };
CircularJSON.stringify = function stringify(value, replacer, space, doNotResolve) {
    return JSON.stringify(
        value,
        CircularJSON.generateReplacer(value, replacer, !doNotResolve),
        space
    );
  };
/*** end of circular-json ***/

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

function createCompatibleContext() {
    let c = vm.createContext();
    vm.runInContext('delete this.console', c, "(execjs)");
    return c;
}

function createPermissiveContext() {
    return vm.createContext({ global: {}, process: {release: {name: "node"}}, Buffer, clearTimeout, require, setTimeout });
}

function getCompatibleContext(uuid) {
    return contexts[uuid] || (contexts[uuid] = createCompatibleContext());
}

function getPermissiveContext(uuid) {
    return contexts[uuid] || (contexts[uuid] = createPermissiveContext());
}

let commands = {
    deleteContext: function(uuid) {
        delete contexts[uuid];
        return [1];
    },
    exit: function(code) {
        process_exit = code;
        return ['ok'];
    },
    execp: function execJS(input) {
        let context = getPermissiveContext(input.context);
        let result = vm.runInContext(input.source, context, "(execjs)");
        if (typeof result === 'undefined' && result !== null) { return ['ok']; }
        else {
            try { return ['ok', result]; }
            catch (err) { return ['err', ['', err].join(''), err.stack]; }
        }
    },
    exec: function execJS(input) {
        let context = getCompatibleContext(input.context);
        let result = vm.runInContext(input.source, context, "(execjs)");
        if (typeof result === 'undefined' && result !== null) { return ['ok']; }
        else {
            try { return ['ok', result]; }
            catch (err) { return ['err', ['', err].join(''), err.stack]; }
        }
    }
};

let server = net.createServer(function(s) {
    let received_data = [];

    s.on('data', function (data) {
        received_data.push(data);
        if (data[data.length - 1] !== 4) { return; }
        
        let request = received_data.join('').toString('utf8');
        request = request.substr(0, request.length - 1);
        received_data = [];
        
        let input, result;
        let outputJSON = '';

        try { input = JSON.parse(request); }
        catch(err) { 
          outputJSON = JSON.stringify(['err', ['', err].join(''), err.stack]);
          s.write([outputJSON, "\x04"].join(''));
          return;
        }

        try { result = commands[input.cmd].apply(null, input.args); } 
        catch (err) { 
          outputJSON = JSON.stringify(['err', ['', err].join(''), massageStackTrace(err.stack)]);
          s.write([outputJSON, "\x04"].join(''));
          return;
        }

        try { outputJSON = JSON.stringify(result); }
        catch(err) {
            if (err.message.includes('circular')) { outputJSON = CircularJSON.stringify(result); }
            else { outputJSON = JSON.stringify([['', err].join(''), err.stack]); }
            s.write([outputJSON, "\x04"].join(''));
            return;
        }

        s.write([outputJSON, "\x04"].join(''));
        if (process_exit !== false) { process.exit(process_exit); }
    });
});

let socket_path = process.env.SOCKET_PATH;
if (!socket_path) { throw 'No SOCKET_PATH given!'; };
if (os.platform().indexOf('win') > -1) { server.listen('\\\\.\\pipe\\' + socket_path); }
else { server.listen(socket_path); }

