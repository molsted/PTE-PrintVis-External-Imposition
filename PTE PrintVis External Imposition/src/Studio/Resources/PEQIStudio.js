// Copyright (c) 2026 Printers Equity. All rights reserved.
//
// Hosts the Impositioning editor in a nested iframe and relays messages between
// it and AL. BC's add-in sandbox cannot load a remote script, but it can frame a
// remote page, so the frame is the integration surface.

var PEQI = (function () {
    'use strict';

    var frame = null;
    var spaOrigin = null;
    var pending = null;

    function originOf(url) {
        var a = document.createElement('a');
        a.href = url;
        return a.protocol + '//' + a.host;
    }

    function fail(message) {
        Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('EditorFailed', [message]);
    }

    function onMessage(event) {
        // Only the framed editor may speak to this control. Without this check
        // any page could post a forged solution into Business Central.
        if (!spaOrigin || event.origin !== spaOrigin) {
            return;
        }
        var data = event.data;
        if (!data || typeof data !== 'object') {
            return;
        }

        switch (data.type) {
            case 'imposition:ready':
                if (pending) {
                    frame.contentWindow.postMessage(pending, spaOrigin);
                    pending = null;
                }
                break;
            case 'imposition:chosen':
                Microsoft.Dynamics.NAV.InvokeExtensibilityMethod(
                    'SolutionChosen', [JSON.stringify(data)]);
                break;
            case 'imposition:preview':
                Microsoft.Dynamics.NAV.InvokeExtensibilityMethod(
                    'PreviewReady', [JSON.stringify(data)]);
                break;
            case 'imposition:error':
                fail(data.message || 'The imposition editor reported an error.');
                break;
        }
    }

    return {
        load: function (spaUrl, requestJson, optionsJson) {
            if (!spaUrl) {
                fail('No editor URL is configured on the Imposition Setup page.');
                return;
            }

            try {
                spaOrigin = originOf(spaUrl);
            } catch (e) {
                fail('The editor URL is not a valid address: ' + spaUrl);
                return;
            }

            pending = {
                type: 'imposition:seed',
                v: 1,
                request: JSON.parse(requestJson),
                options: JSON.parse(optionsJson)
            };

            var container = document.getElementById('controlAddIn');
            container.innerHTML = '';

            frame = document.createElement('iframe');
            frame.setAttribute('title', 'Imposition editor');
            frame.style.width = '100%';
            frame.style.height = '100%';
            frame.style.border = '0';
            frame.src = spaUrl + (spaUrl.indexOf('?') === -1 ? '?' : '&') + 'embed=1';
            frame.onerror = function () {
                fail('The imposition editor could not be loaded from ' + spaOrigin + '.');
            };

            container.appendChild(frame);
            window.addEventListener('message', onMessage, false);
        }
    };
})();

function LoadEditor(spaUrl, requestJson, optionsJson) {
    PEQI.load(spaUrl, requestJson, optionsJson);
}
