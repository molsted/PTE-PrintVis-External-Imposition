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
    var listening = false;

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

    // Resolves the SPA origin, frames the SPA with embed=1 and queues the message
    // that is posted once the SPA announces imposition:ready. Returns false (after
    // reporting through EditorFailed) when the frame cannot be set up.
    function frameSpa(spaUrl, title, message) {
        if (!spaUrl) {
            fail('No editor URL is configured on the Imposition Setup page.');
            return false;
        }

        try {
            spaOrigin = originOf(spaUrl);
        } catch (e) {
            fail('The editor URL is not a valid address: ' + spaUrl);
            return false;
        }

        pending = message;

        var container = document.getElementById('controlAddIn');
        container.innerHTML = '';

        frame = document.createElement('iframe');
        frame.setAttribute('title', title);
        frame.style.width = '100%';
        frame.style.height = '100%';
        frame.style.border = '0';
        frame.src = spaUrl + (spaUrl.indexOf('?') === -1 ? '?' : '&') + 'embed=1';
        frame.onerror = function () {
            fail('The imposition editor could not be loaded from ' + spaOrigin + '.');
        };

        container.appendChild(frame);
        if (!listening) {
            window.addEventListener('message', onMessage, false);
            listening = true;
        }
        return true;
    }

    return {
        load: function (spaUrl, requestJson, optionsJson) {
            frameSpa(spaUrl, 'Imposition editor', {
                type: 'imposition:seed',
                v: 1,
                request: JSON.parse(requestJson),
                options: JSON.parse(optionsJson)
            });
        },

        loadBook: function (spaUrl, jdfXml, optionsJson) {
            var options;
            try {
                options = optionsJson ? JSON.parse(optionsJson) : undefined;
            } catch (e) {
                fail('The book preview options are not valid JSON.');
                return;
            }

            var message = { type: 'book:seed', v: 1, jdf: jdfXml };
            if (options) {
                message.options = options;
            }
            frameSpa(spaUrl, 'Book preview', message);
        }
    };
})();

function LoadEditor(spaUrl, requestJson, optionsJson) {
    PEQI.load(spaUrl, requestJson, optionsJson);
}

function LoadBook(spaUrl, jdfXml, optionsJson) {
    PEQI.loadBook(spaUrl, jdfXml, optionsJson);
}
