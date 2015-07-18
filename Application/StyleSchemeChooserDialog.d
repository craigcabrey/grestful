/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module Application.StyleSchemeChooserDialog;

import gtk.Box;
import gtk.Dialog;

import gsv.SourceStyleScheme;
import gsv.StyleSchemeChooserWidget;

import Generic.Signal : Signal;
import Generic.Buildable : Buildable;

import Application.Class : ApplicationClass = Class;
import Application.Utility;

/**
 * The main application window.
 */
class StyleSchemeChooserDialog : Buildable!Dialog
{
public:
    static Signal!("styleSchemeChanged", typeof(this), SourceStyleScheme) styleSchemeChangedSignal;

public:
    /**
     * Constructor.
     *
     * @param application Application instance.
     */
    this(ApplicationClass application)
    {
        super(APPLICATION_DESIGN_DIR ~ "StyleSchemeChooserDialog.glade", "styleSchemeChooserDialog");

        //this.setupLayout();
        this.connectHandlers();
    }

protected:
    /**
     * Connects event handlers for the object.
     */
    void connectHandlers()
    {
        auto mainBox = this.getWidget!Box("mainBox");

        this.styleSchemeChooserWidget = new StyleSchemeChooserWidget();

        // NOTE: This is not added in the builder file because for some reason Glade will not fetch the item by ID or
        // list it in the objects. This is presumably because the type is not correctly registered.
        mainBox.packStart(styleSchemeChooserWidget, true, true, 0);
        mainBox.showAll();

        this.styleSchemeChooserWidget.addOnNotify(delegate(ParamSpec, ObjectG) {
            this.styleSchemeChangedSignal.send(
                this,
                this.styleSchemeChooserWidget.getStyleScheme()
            );
        }, "style-scheme");
    }

protected:
    /**
     * The style scheme chooser widget.
     */
    StyleSchemeChooserWidget styleSchemeChooserWidget;
}
