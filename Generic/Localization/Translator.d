/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module Generic.Localization.Translator;

 /**
  * The translation function. Returns the string, translated in the currently active locale.
  *
  * @param text The text to translate.
  *
  * @return The translated text.
  *
  * @note Does nothing but return the string at the moment, but should still be used so it can be implemented easily in
  *       the future.
  */
string _(string text)
{
    return text; //return text in map ? map[text] : text;
}
