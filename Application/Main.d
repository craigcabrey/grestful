/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module Application.Main;

import std.conv;

import gtk.Main;
import gtk.Version;
import gtk.MessageDialog;

import Application.Class : ApplicationClass = Class;
import Application.Utility;

/**
 * Application entry point.
 *
 * @param args The arguments passed to the application.
 *
 * @return The status code to return to the invoker.
 */
int main(string[] args)
{
    string error = Version.checkVersion(GTK_VERSION_MAJOR, GTK_VERSION_MINOR, GTK_VERSION_PATCH);

    if (error !is null)
    {
        Main.init(args);

        MessageDialog dialog = new MessageDialog(
            null,
            DialogFlags.MODAL,
            MessageType.ERROR,
            ButtonsType.OK,
            _("Your GTK version is too old, you need at least GTK ") ~
                to!string(GTK_VERSION_MAJOR) ~ '.' ~
                to!string(GTK_VERSION_MINOR) ~ '.' ~
                to!string(GTK_VERSION_PATCH) ~ '!',
            null
        );

        dialog.setDefaultResponse(ResponseType.OK);

        dialog.run();
        return 1;
    }

    return (new ApplicationClass()).run(args);
}
