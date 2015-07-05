/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module Application.MainWindow.HeaderBar;

import gio.Menu;

import gtk.Grid;
import gtk.Image;
import gtk.Stack;
import gtk.Widget;
import gtk.Window;
import gtk.MenuButton;
import gtk.StackSwitcher;

static import gtk.HeaderBar;

import Application.Utility;
import Application.Class : ApplicationClass = Class;

/**
 * Defines the header bar that serves as the title bar for the application.
 */
class HeaderBar : gtk.HeaderBar.HeaderBar
{
public:
    /**
     * Constructor.
     */
    this(Window parentWindow, ApplicationClass application)
    {
        this.setShowCloseButton(true);

        this.viewStack = new Stack();
        this.viewStack.setHomogeneous(true);
        this.viewStack.setTransitionType(StackTransitionType.SLIDE_LEFT_RIGHT);

        StackSwitcher viewSwitcher = new StackSwitcher();
        viewSwitcher.setStack(this.viewStack);

        this.setCustomTitle(viewSwitcher);

        // The grid that displays the buttons on the left of the view tabs in the header bar.
        Grid leftGrid;

        with (leftGrid = new Grid())
        {
            MenuButton fileButton;
            Menu section, fileMenu = new Menu();

            with (application)
            {
                registerAction("app.new-file",           "<Primary>N");
                registerAction("app.open-file",          "<Primary>O");
                registerAction("app.reopen-last-closed", "<Primary><Shift>T");
                registerAction("app.save-file",          "<Primary>S");
                registerAction("app.save-file-as",       "<Primary><Shift>S");
                registerAction("app.reload-from-file",   "<Primary><Shift>R");
                registerAction("app.close-current-file", "<Primary>W");
            }

            fileMenu.append(_("_New"), "app.new-file");

            with (section = new Menu())
            {
                append(_("_Open..."),               "app.open-file");
                append(_("_Reopen Last Closed..."), "app.reopen-last-closed");
                append(_("_Save"),                  "app.save-file");
                append(_("Save _As..."),            "app.save-file-as");
            }
            fileMenu.appendSection(null, section);

            with (section = new Menu())
            {
                append(_("_Reload From File"),      "app.reload-from-file");
            }
            fileMenu.appendSection(null, section);

            with (section = new Menu())
            {
                append(_("_Close"),                 "app.close-current-file");
            }
            fileMenu.appendSection(null, section);

            with (fileButton = new MenuButton())
            {
                setLabel(_("File"));
                setMenuModel(fileMenu);
            }

            add(fileButton);
        }

        this.packStart(leftGrid);

        // The grid that displays the buttons on right of the view tabs in the header bar.
        Grid rightGrid = new Grid();
        {
            MenuButton wheelButton;
            Menu section, wheelMenu = new Menu();

            with (application)
            {
                registerAction("app.toggle-file-browser");
                registerAction("app.view-defaults", "<Primary>F1");
                registerAction("app.edit-settings", "<Primary>F2");

                registerAction("app.split-horizontally");
                registerAction("app.split-vertically");
                registerAction("app.merge-cells");
            }

            wheelMenu.append(_("_File Browser"), "app.toggle-file-browser");

            with (section = new Menu())
            {
                append(_("View _Defaults"), "app.view-defaults");
                append(_("_Edit Settings"), "app.edit-settings");
            }
            wheelMenu.appendSection(null, section);

            with (section = new Menu())
            {
                append(_("Split _Horizontally"), "app.split-horizontally");
                append(_("Split _Vertically"),   "app.split-vertically");
                append(_("_Merge Split Cells"),  "app.merge-cells");
            }
            wheelMenu.appendSection(null, section);

            with (wheelButton = new MenuButton())
            {
                // Will automatically use an icon specific for dropdown menu's that don't have a specific direction
                // (i.e. 'open-menu-symbolic' in GTK 3.14).
                //setMenuDirection(GtkArrowType.NONE);

                setImage(new Image("open-menu-symbolic", IconSize.MENU));
                setMenuModel(wheelMenu);
            }

            rightGrid.add(wheelButton);
        }

        this.packEnd(rightGrid);

        parentWindow.add(this.viewStack);

        this.showAll();
    }

public:
    @property
    {
        /**
         * Property to access the stack that contains the buttons that activate the individual views.
         */
        auto ViewStack()
        {
            return this.viewStack;
        }
    }

public:
    /**
     * Adds a new view to the header bar.
     *
     * @param string title The title of the view and also the text to put on the button in the header bar.
     * @param Widget view  The actual widget to show when the view is activated by clicking the button.
     */
    void addView(string title, Widget view)
    {
        this.viewStack.addTitled(view, title ~ "View", title);
        view.show(); // TODO: Remove this later when each view is an actual class and can show itself.
    }

private:
    /**
     * The header stack.
     */
    Stack viewStack;
}
