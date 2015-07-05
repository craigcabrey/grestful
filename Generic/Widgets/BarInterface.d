/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module Generic.Widgets.BarInterface;

import gtk.Widget;

/**
 * Describes functionality that must be exposed by components that behave as a bar in the edit view (e.g. a search bar
 * that displays itself at the top).
 */
interface BarInterface
{
public:
    @property
    {
        /**
         * Indicates whether the bar is currently open or not.
         */
        bool IsOpen();

        /**
         * Returns the widget of the cell that can be added to the edit view.
         */
        Widget GtkWidget();
    }

public:
    /**
     * Opens the bar, revealing it and moving user input focus to it.
     */
    void open();

    /**
     * Closes the bar, hiding it from the user.
     */
    void close();
}
