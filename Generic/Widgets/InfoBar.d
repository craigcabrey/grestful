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
         * @copydoc BarInterface::IsOpen
         */
        bool IsOpen()
        {
            return (this.getVisible() != 0);
        }

        /**
         * @copydoc BarInterface::GtkWidget
         */
        Widget GtkWidget()
        {
            return this;
        }
    }

public:
    /**
     * Shows a message in the info bar with the specified message and type.
     *
     * @param message The message to show.
     * @param type    The type of message that is to be displayed.
     */
    void showMessage(string message, MessageType type = MessageType.ERROR)
    {
        this.message.setText(message);
        this.setMessageType(type);

        this.open();
    }

public:
    /**
     * @copydoc BarInterface::open
     */
    void open()
    {
        this.setNoShowAll(false);
        this.showAll();
        this.setNoShowAll(true);
    }

    /**
     * @copydoc BarInterface::close
     */
    void close()
    {
        this.hide();
    }

private:
    /**
     * Called when one of the action widgets in the infobar was clicked.
     *
     * @param responseId The info bar response code (determines what type of action was performed).
     * @param sender     The sender of the event.
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
