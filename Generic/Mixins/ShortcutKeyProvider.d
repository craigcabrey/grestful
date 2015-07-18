/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module Generic.Mixins.ShortcutKeyProvider;

import std.typecons;

/**
 * Mixin that can be used by classes that need to attach certain key bindings to methods. Typically you would define a
 * key handler using addOnKeyPress, check for the appropriate key and finally invoke your method. Using this mixin you
 * can instead use the UDA (User Defined Attribute) {@see Shortcut} below to specify the shortcut for the method.
 */
mixin template ShortcutKeyProvider()
{
    import gtk.Widget;
    import gdk.Event;
    import Generic.Utility;

protected:
    /**
     * The key handler. Install this as soon as your widget is created using addOnKeyPress.
     *
     * @param e The raw event.
     * @param w The sender.
     *
     * @return Whether or not the event should propagate.
     */
    bool onKeyPress(Event e, Widget w)
    {
        uint key;
        GdkModifierType modifier;

        if (!e.getKeyval(key) || !e.getState(modifier))
            return EventPropagation.PROPAGATE;

        foreach (member; __traits(allMembers, typeof(this)))
        {
            foreach (attribute; __traits(getAttributes, __traits(getMember, typeof(this), member)))
            {
                static if (is(typeof(attribute) : Shortcut))
                {
                    uint bindingKey;
                    GdkModifierType bindingMods;

                    import gtk.AccelGroup;

                    AccelGroup.acceleratorParse(
                        (cast(Shortcut) attribute).accelerator,
                        bindingKey,
                        bindingMods
                    );

                    // These checks are needed as we can't force the modifiers to be the same; numlock may count as
                    // modifier on some systems and only appear in the event modifiers, but it will not appear in our
                    // shortcut modifier.

                    if (((bindingMods & GdkModifierType.CONTROL_MASK) ^ (modifier & GdkModifierType.CONTROL_MASK)) != 0)
                        continue; // Either control is set when it's not required or it isn't set while it is required.

                    else if (((bindingMods & GdkModifierType.MOD1_MASK) ^ (modifier & GdkModifierType.MOD1_MASK)) != 0)
                        continue; // Same for mod 1 (alt).

                    else if (((bindingMods & GdkModifierType.SHIFT_MASK) ^ (modifier & GdkModifierType.SHIFT_MASK)) != 0)
                        continue; // Same for shift.

                    else if (key == bindingKey && (modifier & bindingMods) == bindingMods)
                    {
                        mixin("return this." ~ member ~ "(e);");
                    }
                }
            }
        }

        return EventPropagation.PROPAGATE;
    }
}

/**
 * This is only used as type in UDA's (User Defined Attributes).
 *
 * @example @Shortcut("<Control><Shift>Up") void MyFunctionThatIsCalledOnThatShortcut() { ... }
 */
alias Shortcut = Tuple!(string, "accelerator");
