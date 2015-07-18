/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module Generic.Buildable;

import gobject.ObjectG;

static import gtk.Widget;
static import gtk.Builder;

/**
 * Base class for classes that are actually GTK widgets, but build their lay-out from a GtkBuilder XML file instead
 * (i.e. they are not actually GtkWidgetS but are more or less a wrapper for them).
 */
abstract class Buildable(T = gtk.Widget.Widget)
{
public:
    /**
     * Constructor.
     *
     * @param builder The builder definition file to load that contains the buildable object.
     * @param id      The ID of the buildable object (ID of the widget or object in the file).
     */
    this(string filename, string id)
    {
        this.id = id;
        this.builder = new gtk.Builder.Builder(filename);
    }

    /**
     * Constructor that initializes the object with an existing builder object.
     *
     * @param builder The builder to use that has the definition file containing the buildable object loaded.
     * @param id      The ID of the buildable object (ID of the widget or object in the file).
     */
    this(gtk.Builder.Builder builder, string id)
    {
        this.id = id;
        this.builder = builder;
    }

public:
    @property
    {
        /**
         * Fetches the builder object.
         *
         * @return The builder object.
         */
        gtk.Builder.Builder Builder()
        {
            return this.builder;
        }

        /**
         * Fetches the main ObjectG at the root of the widget tree described by the GtkBuilder file.
         *
         * @return The object.
         */
        T Object()
        {
            return this.getObject!T(this.id);
        }

        /**
         * Fetches the main GtkWidget at the root of the widget tree described by the GtkBuilder file.
         *
         * @return The widget.
         */
        T Widget()
        {
            return this.getWidget!T(this.id);
        }
    }

public:
    /**
     * Fetches the object with the specified ID from the object tree described by the builder file.
     *
     * @param id The ID to look for.
     *
     * @return The object.
     *
     * @note Objects are cached when they are first retrieved so multiple retrievals is not expensive.
     */
    S getObject(S = ObjectG)(string id)
    {
        if (id !in this.objectCache)
            this.objectCache[id] = cast(S) this.Builder.getObject(id);

        return cast(S) this.objectCache[id];
    }

    /**
     * Fetches the widget with the specified ID from the object tree described by the builder file.
     *
     * @param id The ID to look for.
     *
     * @return The object.
     *
     * @note Objects are cached when they are first retrieved so multiple retrievals is not expensive.
     */
    alias getWidget(S = gtk.Widget.Widget) = getObject!S;

protected:
    /**
     * The ID of the object (also used in the GtkBuilder file).
     */
    string id;

    /**
     * A list of objects that have already been retrieved, kept here to prevent having to fetch it multiple times from
     * the builder.
     */
    ObjectG[string] objectCache;

    /**
     * The builder object containing usable to fetch widgets that were created as per the (GtkBuilder) file fed to it.
     */
    gtk.Builder.Builder builder;
}
