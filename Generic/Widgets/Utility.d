/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module Generic.Widgets.Utility;

import gtk.TextIter;
import gtk.TextMark;
import gtk.TextBuffer;

/**
 * Mixin template that allows conveniently restoring the current selection and cursor by using marks that maintain
 * their location by using the specified gravity.
 */
mixin template SelectionStorage()
{
    TextMark selectionStorageStartMark, selectionStorageEndMark;

    /**
     * Stores the selection using marks (as iterators can become invalidated when text is modified). Nesting calls to
     * this method is not supported.
     *
     * @param buffer      The buffer to work with.
     * @param leftGravity Whether to use left gravity for the marks or not. If you wish to mimic the cursor, you
     *                    probably want right gravity.
     */
    void storeSelection(TextBuffer buffer, bool leftGravity)
    {
        TextIter selectionEnd   = buffer.getSelectionBound().getIter();
        TextIter selectionStart = buffer.getInsert().getIter();

        // GTK 3.14.7: For some reason, getSelectionBounds does not always retrieve the same result as fetching the
        // location of the marks individually as above. This results in selections using <Shift>Right to bug out due to
        // the restoreSelection in CodeEditor::onMoveCursor.
        //buffer.getSelectionBounds(selectionStart, selectionEnd);

        selectionStorageEndMark   = buffer.createMark(null, selectionEnd,   leftGravity);
        selectionStorageStartMark = buffer.createMark(null, selectionStart, leftGravity);
    }

    /**
     * Restores the selection using the previously saved state.
     *
     * @param buffer The buffer to work with.
     */
    void restoreSelection(TextBuffer buffer)
    {
        TextIter selectionEnd   = selectionStorageEndMark.getIter();
        TextIter selectionStart = selectionStorageStartMark.getIter();

        buffer.selectRange(selectionStart, selectionEnd);

        buffer.deleteMark(selectionStorageEndMark);
        buffer.deleteMark(selectionStorageStartMark);
    }
}

/**
 * Convenience function that directly returns a TextIter at the location of the mark.
 *
 * @param mark The mark to retrieve the iter from.
 *
 * @return The iterator.
 */
TextIter getIter(TextMark mark)
{
    TextIter iter = new TextIter();
    mark.getBuffer().getIterAtMark(iter, mark);

    return iter;
}

/**
 * Convenience function that indicates if the specified iterator demarcates a line (i.e. it's at the start or end of a
 * line).
 *
 * @param iter The iterator to use.
 *
 * @return Whether or not the iterator demarcates a line.
 */
bool demarcatesLine(TextIter iter)
{
    return (iter.startsLine() || iter.endsLine());
}
