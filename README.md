
Clicking
--------

Clicking on a component results in two actions:

* an inspector is displayed
* the component text becomes editable via the keyboard


Hovering
--------

When a component is hovered, the following controls appear:

* delete button at the upper-left corner of the component
* duplicate button to the right of the delete button
* resize handles at the top, right and bottom edges, and in the top-right, bottom-right and bottom-left corners

When a container is hovered, a move handle additionally appears close to the left edge of the component.

When the hovered component is part of a stack, additional stack insertion buttons appear at the sides where a new stack item may be inserted.

The buttons are semi-transparent until they are hovered. When a button is hovered, a textual hint is displayed close to it. When a stack insertion button is hovered, a hint appears that shows a preview of the component that would be added into the stack.

Most buttons are located exactly on the edge of the component, but some (move handle, stack insertion buttons) are completely outside.

It is normal for several component to be considered hovered at the same time. A component below the outside buttons is hovered when you reach for the buttons. Also, if a hovered component is close to the edge of its parent container, the container is hovered too.



Dragging
--------

You can drag:

* an existing non-container by holding the mouse anywhere inside its bounds
* an existing container by holding a Move handle
* a new component from the Add popover

You can press ESC anytime to cancel the drag. Additionally, you can release the component outside of the design area to cancel the drag.

The following feedback occurs while dragging:

* while the dragged component is outside the design area, it is ghosted to indicate an invalid drag
* tracking triggers appear on all components
* if there is a set of recommended locations for the component in the current target container, those locations are filled with a ghost copy of the dragged component, inviting to drop it there
* if the dragged component is close to an anchoring position, it is anchored live
* if the component is dragged over a stack and may become a part of the stack, the stack items move aside to give place for the component, and a ghost copy is placed to the corresponding drop location
* in any case, components are not expected to overlap (excluding certain components like popups and keyboards), so while you are dragging over other components and they are not stackable, you cannot drop
* when the above rules do not apply, the dragged component follows the mouse cursor


Dropping
--------

The rules of dropping are easy: if the dragged component was black, it stays where it was at the moment of drop. (So to actually drop a component somewhere, you should move it close so that it gets live anchored.) If the dragged component was semi-transparent indicating an invalid drag, the drag is cancelled.


Autosizing
----------

When a component is auto-resized, it causes other components to move if those components were close enough.

Some components are optionally autosized. E.g. a label is always autosized vertically, but can be given a specific horizontal size, in which case it is wrapped. Additionally, a label never gets wider than its container, so it maybe wrap even in autosize-width mode.


Anchoring
---------

Anchoring helps to position the component in exact positions. There are several types of positions that a dragged component may anchor to:

* center of another component in the same container
* edge of another component in the same container
* baseline of another component in the same container
* recommended distance from another component
* recommended location for this component in the container
* location in a stack
* tracking point

To avoid displaying too many anchors, the anchors are given priority by the proximity of the their inducing components. A subset of possible anchors is then chosen such that the distance between any two anchors is at least 3 pixels.

Baseline and center alignments are probably alternates, and one or another is picked depending on the nature of the components.


Tracking
--------

Tracking is a way to manually specify the edge you want to anchor to. Every possible anchoring position (edge, center) of any component in the design area is available for tracking.

When dragging starts, all possible tracking points are highlighted. To start tracking, you just drag your mouse over a tracking point.

At any given moment, there may be one current horizontal tracking point and one current vertical tracking point. Initially, both are undefined. After you hover your mouse over a tracking point, it becomes the current horizontal or vertical point.

As you continue to move your mouse approximately at the right horizontal or vertical position, a dashed tracking guide is displayed. If you move your mouse too far, the tracking guide is hidden, and tracking does not occur. But if you return your mouse back to approximately the right location, the tracking is resumed.

This way, you can first activate horizontal tracking, then pick a point for vertical tracking, then move your mouse to the approximate point of their intersection, and click to pick it.


Stacks
------

A stack is a set of similar components located close to each other. Examples include table rows, tab bar items, buttons in a popup box. A stack is recognized automatically when two or more similar components are closely located and evenly spaced.

Stacking depends on the type of the components. Some components always form a stack on their own — table rows in particular. Almost any kind of components may form a vertical stack.

The goal is to stack components that look like they were placed together.


A stack affects the behaviour of the designer in the following ways:

* when a component is dragged away from the stack, other components are moved to fill the vacant place
* when a component is dragged into the stack, other components move away to give place to the new item
* you can rearrange components within a stack as you would expect
* additional stack insertion buttons are available when stacking components are hovered, allowing to insert a similar component at one of the sides

An alignment of the stack is recognized (centered, left, right or fill-width), and when the components are added or removed, components are layouted accordingly (moved to the left, to the right, to both sides, or resized).


Empty space
-----------

If you move a component away, it leaves an empty space unless that component was part of a stack. Getting rid of this space may be a hassle since it requires moving all other components manually. To automate this process, in certain cases the empty space between components can be resized like a real component (causing other components to move around).

An empty space may be treated like a component if:

* it is large enough (say more than 40px)
* a component was recently moved out of it, and it is larger than tiny (say, more than 5px)

Such empty spaces should be marked in some way.


A note on proximity/margins
---------------------------

By proximity components may be related in 3 ways:

* stacked: close enough and similar enough
* close: close enough, but not similar enough to be stacked
* far: not close enough


Containment
-----------

Containment of components is determined based on their location. A component which is located inside (or overlaps an edge of) a container belongs to that container. A component which overlaps several containers does not belong to any of them (or maybe that's forbidden altogether).

Contained components are moved, deleted or duplicated when the container is moved, deleted or duplicated.


Persistent state
----------------

There is no hidden state aside from the one visible on the screen. In particular, it does not matter if a component has been placed via anchoring or by manual positioning.

It is okay to special-case some components based on being anchored in a specific way, but that special casing will apply to any component that happens to be located at the right place.

Seems that anchoring information should still be saved, so that if the anchoring algorithm changes slightly (say, ±1 pixel), previously anchored components wouldn't loose their special status. The same safety could be achieved by other means, however — for example, the anchored location may be matched fuzzily (±n pixels), or older versions of the algorithm may participate in matching.

We must be able to quickly match components to the anchoring positions, and this information should probably be exported for use by external tools (and our own HTML/iPhone exporting).


Keyboard editing
----------------

The usual stuff. Arrows shift by one pixel, shift+arrows shift by 10. A shortcut to duplicate the component to any side. A shortcut to move to the next component in the given direction.


Components
----------

* Status Bar
* Tab Bar
* Navigation Bar

* Bar Button
* Colored Button
* Rounded Button
* Buy Button
* Toggle
* Slider
* Progress Bar
* Progress Indicator
* Segmented Control
* Stars

* Picker

Plain Table:
* Header
* Row
  - label
  - image + label
  - label >> rlabel
  - rlabel + label
  - label, sublabel 
  - image + title, subtitle
  - image + title, multiline description
* Footer
* Accessories:
  - disclosure indicator
  - disclosure button
  - reorder handle
  - checkmark
  - insert
  - delete
* Index

Grouped Table:
* Header
* Row (same styles)
* Footer
* Accessories

* Alert Panel
* Keyboard

* Scroll Bar (add to make a component scrollable!)


Screen
------

Screen is the top-level component. It may have a status bar, a navigation bar, a tab bar, and regular children.





