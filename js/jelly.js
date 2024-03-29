/*=============================================================================//
The MIT License (MIT)

Copyright (c) 2014 RepeatPan
excluding parts that were written by Radiant Entertainment

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
//=============================================================================*/

var tracer;
var data = {};

jelly = {
   // Prints something to the console
   print : function()
   {
      return radiant.callv('jelly:print', arguments);
   },
   
   // Returns the value of a previously lua-stored value.
   // These values are not saved in the game, but persist until the game is restarted.
   get_data: function(key)
   {
      return data[key];
   },
   
   // Stores a variable in the lua state to persist through UI reloads.
   store_data: function(key, value)
   {
      //data[key] = value; // "caching" would be useful, but not desired for debugging
      return radiant.call('jelly:store_data', key, value);
   }
};

radiant.call('jelly:_get_server_data_store').done(function(o) {
   tracer = radiant.trace(o.data_store).progress(function(update)
   {
      $.each(update.calls, function (k, v)
      {
         radiant.callv(v.fn, v.args);
      });
      
      data = update.data;
   });
});

// Patch errors to the console
var oldError = window.onerror;

window.onerror = function(errorMsg, url, lineNumber)
{
   errorMsg = errorMsg || '(unknown error message)';
   url = url || '(unknown url)';
   lineNumber = lineNumber || '(unknown line number)';
   
   jelly.print('ERROR: ' + url + ':' + lineNumber + ': ' + errorMsg);

   if (typeof oldError != 'undefined' && oldError != null)
      return oldError(errorMsg, url, lineNumber);
   
   return false;
}

$(top).trigger('jelly.PostJellyInit');