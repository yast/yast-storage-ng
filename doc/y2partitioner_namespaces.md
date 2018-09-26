# The `Y2Partitioner` namespaces

## About this document

The code organization of the Partitioner may not be obvious, specially since
some of the original ideas and design goals had not always being followed for
different reasons. This document tries to explain what the original idea was,
no matter how closely the ideas has been followed or whether we plan to stick to
them.

## The general idea

Although `CWM` somehow encourages having quite some business logic in the view
layer (every so-called "widget" is potentially a full-featured component able to
fetch and process the related information, to perform complex validations and to
communicate with other widgets/components), one of the design goals of the
Partitioner was to have as little business logic as possible in the dialogs and
widgets.

In other words, the goal was to keep the view layer as "dumb" as possible, so
the `#validate`, `#init` or `#store` methods of some widget here or there does
not contain the logic about things like how to process subvolumes when a new
Btrfs file-system is created or which devices can be selected to create a new
LVM or whether deleting a given device is allowed or not under some
circumstances.

## The `Y2Storage::Actions` namespace

The way of keeping the widgets and dialogs clean from that partitioner-specific
business logic was encapsulating such logic in one class per every action
allowed by the Partitioner. As said, the actions should contain only
partitioner-specific business logic. The more general logic that applies to all
possible uses of the devices (like calculating subvolumes shadowing or
performing extra steps that are needed when creating a file-system of a
particular type) should be implemented directly in the `Y2Storage` classes, to
ensure consistency in how the devices are used in the Partitioner, the Guided
Setup, AutoYaST or any other YaST component.

Every action class implements a method `#run` that returns a symbol:

 * `:back` means the action was not performed. Either because it's not possible
   or because the user regreted during the process. In the first case, is
   expected that the action notifies the reason to the user (via a pop-up) if
   needed as part of `#run`, before returning the symbol.
 * `:finish` means the action has been completed and the interface needs to
   be redrawn to reflect any change performed by the action in the current
   devicegraph.
 * `:quit` tell the Partitioner to terminate.

Many actions do not need extra information from the user, so they don't need to
implement any UI except a pop-up to ask for confirmation or to notify why the
action cannot be performed. This is specially true for delete operations.

But in some cases, the action needs to open a dialog to ask the user some
parameters that are needed to perform the operation. In those cases, it's
expected that the corresponding business logic, like calculating the possible
values to be offered to the user or making the user selection effective in the
current devicegraph, resides in the action class, with the dialog (and its
widgets) being basically a thin presentation layer.

A good example of that is the current (at the moment of writing)
`Actions::CreatePartitionTable` and its relationship with the corresponding
(pretty simple and dumb) dialog `Dialogs::PartitionTableType`.

## Sequences and the `Actions::Controllers` namespace

Some Partitioner actions can get quite complicated and take several UI steps in
a wizard before they can be completed. In those cases, the action object does
not only have to hold the business logic, but it also has to control the
execution flow. That is, deciding which steps are presented in which order,
passing the information from one step to another and, in short, coordinating the
whole sequence of dialogs.

That's how we ended up breaking those actions into two pieces. On one hand, the
action object which in this case is limited to basically control the sequence of
steps and return one of the symbols explained above when the sequence is over
(succesfully, aborted or simply not started). On the other hand, a controller
object (nothing to do with the role of a controller in the MVC pattern) which
contains the business logic and stores the intermediate result and the
information introduced by the user in previous steps of the sequence.

So only action objects that represent wizards (a.k.a. sequences) rely on some
corresponding classes in the `Y2Partitioner::Actions::Controllers`. Note there
is not always a 1:1 relationship between classes in the `Actions` and the
`Controllers` namespaces. In some cases, the same controller class is used by
several action classes. On the other hand, some complex and long wizards use
more than one controller class.

## The base class `Actions::TransactionWizard`

Due to the nature of libstorage-ng, some business logic that lives in the
`Y2Storage` namespace can only be used when some devices have been already
created and deleted in the devicegraph. For example, to know if an MD RAID
is valid or to calculate its size, the MD device must be already created in the
devicegraph with a chosen name/number and the corresponding partitions/disks
must have been already associated to the RAID. In order to do so, all the
previous devices (like file-systems or LVMs) depending on those partitions/disks
must be deleted. A pretty aggressive set of actions to be performed on the
current devicegraph just to be able to visualize a temptative size or to move
some devices in a temporary list.

To handle those cases, an action can be implemented as a subclass of
`Actions::TransanctionWizard`. That base class contains logic to take a snapshot
of the current devicegraph when the action is starting, rolling back any change
if the action is not completed successfully.

Several complex wizards are subclasses of `TransactionWizard` and rely on one or
several controller objects (the would work directly on the current devicegraph,
not knowing they are part of an atomic transaction). But in general, the usage
of controllers or transactions is not needed, so such mechanisms should only be
added to an action when there is a real need.
