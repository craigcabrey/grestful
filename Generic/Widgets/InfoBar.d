/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module Generic.Widgets.InfoBar;

import gtk.Label;
import gtk.Widget;

static import gtk.InfoBar;

import Generic.Widgets.BarInterface;

/**
 * A convenience subclass of GtkInformationBar that allows to show messages to the user without having to pop up a
 * dialog.
 */
class InfoBar : gtk.InfoBar.InfoBar, BarInterface
{
public:
    /**
     * Constructor.
     */
    this()
    {
        this.setShowCloseButton(true);
        this.message = new Label("");

        this.setNoShowAll(true);
        this.addOnResponse(&onWidgetClicked);

        this.getContentArea().add(this.message);
    }

public:
    @property
    {
        /**
         * {@inheritDoc}
         *
         * Realizes functionality from {@see BarInterface}.
         */
        bool IsOpen()
        {
            return (this.getVisible() != 0);
        }

        /**
         * {@inheritDoc}
         *
         * Realizes functionality from {@see BarInterface}.
         */
        Widget GtkWidget()
        {
            return this;
        }
    }

public:
    /**
     * Shows a message in the info bar with the specified message and type.
     */
    void showMessage(string message, MessageType type = MessageType.ERROR)
    {
        this.message.setText(message);
        this.setMessageType(type);

        this.open();
    }

public:
    /**
     * {@inheritDoc}
     *
     * Realizes functionality from {@see BarInterface}.
     */
    void open()
    {
        this.setNoShowAll(false);
        this.showAll();
        this.setNoShowAll(true);
    }

    /**
     * {@inheritDoc}
     *
     * Realizes functionality from {@see BarInterface}.
     */
    void close()
    {
        this.hide();
    }

private:
    /**
     * Called when one of the action widgets in the infobar was clicked.
     */
    void onWidgetClicked(int responseId, gtk.InfoBar.InfoBar sender)
    {
        if (responseId == ResponseType.CLOSE)
            sender.hide();
    }

private:
    /**
     * The message displayed in the infobar.
     */
    Label message;
}
