## Idea: Constrain-based Definitions

This is part of the [bigger document](../../partitioner_ui.md) about rethinking the YaST Partitioner
user interface.

This is a very experimental idea that would probably fit better as a new way of refining the
partitioning proposal than as a general Partitioner approach. Still, is presented here as an clear
example of the kind of innovations that could be tried.

The idea is based on the Autodesk Inventor for mechanical designs. Where the user basically defines
relations and the inventor models how the result would look like visually. If the users are still
not satisfied with the result, they can add another constraint (like size here, angle there or hard
joint of parts...) and the inventor will model a new result. The process goes on until finding a
final design.

In the YaST context, the users would start with the current partitioning (or current proposal) and
would change it by adding requisites to the result. For example, specifying they want to add LVM
and defining that they want the root file system on it but not the `/home` one. The system would
show how that could like. If the user is still not satisfied, we could add another contraint, like
like encryption for the home mount point or a fixed size for the root file system, and the system
would compute a new proposed layout.
