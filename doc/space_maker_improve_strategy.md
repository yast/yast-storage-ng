# Improving the SpaceMaker strategy

## About this document

This should be a short-lived document. The goal is to discuss the
problems/limitations of the current main algorithm of
`Proposal::SpaceMaker#make_space` and to propose a better
one if possible.

## The current algorithm

Currently SpaceMaker performs its actions in a disk one after another (until it
manages to make enough space to install the system) in a quite dumb order:

  -  Step 1
    - Performed if: resizing Windows is allowed AND there are no Linux
      partitions on the disk.
    - What: tries to resize all the Windows partitions, one after another
      until making enough space.
  - Step 2
    - Performed if: deleting Linux partitions is allowed.
    - What: deletes Linux partitions one by one from the end of the disk.
  - Step 3
    - Performed if: deleting "other" partitions is allowed
    - What: deletes other (non-Windows) partitions one by one from the end
      of the disk.
  - Step 4
    - Performed if: resizing Windows is allowed, no matter whether there are
      Linux partitions on the disk.
    - What: tries to resize all the Windows partitions, one after another until
      making enough space.
  - Step 5
    - Performed if: deleting Windows partitions is allowed.
    - What: deletes Windows partitions one by one from the end of the disk.
  - Step 6
    - Performed if: the disk contains something that is NOT a partition table.
    - What: remove disk content. This step is in fact something like a fallback
      for all the previous steps. It only makes sense when none of the previous
      steps make sense.

## Problems, limitations and weirdness of the current algorithm

Why to change the algorithm? Of course, there are some "code smells" that
somehow seem to indicate fundamental flaws, like the fact of having two
steps that do the same (steps 1 and 4) or having a last step which is
actually not subsequent to the previous steps but an alternative to them (the
algorithm either executes steps 1-5 or only step 6). But the real reason to
propose a change of approach is to easily accommodate changes that has been
requested via Fate, Bugzilla or other channels. Also to overcome several
situations in which the proposal behavior can look erratic, as reported often
and summarized at [Ivan's presentation at oSC'18](https://youtu.be/_0VKUjFAIwo).

### Deleting some partition only as last resort

Several feature requests for SLE-15-SP1 ask to modify the proposal behavior to
ensure that some specific partitions (that would fall into the "others"
category) are only deleted as last resort... or not deleted at all.

See for example [fate#325885](https://fate.suse.com/325885) (about trying to
keep the IRST partitions) or [fate#323484](https://fate.suse.com/323484) (about
installing in a Raspberry Pi).

Several criteria (like the architecture) can influence on deciding which
partitions should SpaceMaker try to keep and how hard should it try to do so
(eg. whether is preferrable to delete Windows partitions).

This is the main reason leading to reconsider the current fixed order of
actions.

### Deleting partitions in a more sensible and reasonable order

As a generalization of the point above, we have received some feedback (and also
identified some cases ourselves) about the SpaceMaker following an unpleasant
order while deleting partitions. The current SpaceMaker simply deletes all Linux
partitions first (sorted by their position in the disk), all "other" partitions
after (also in positional order) and finally all Windows partitions (again, by
position).

In several bug reports (e.g.
[bsc#1090383](https://bugzilla.suse.com/show_bug.cgi?id=1090383)) and
conversations, it has been pointed that some partitions should be considered as
"less-appealing" to be deleted than others, based on their size or even
their content.

Iván's presentation at oSC'18 includes several other examples in which
following the current fixed order may result in not-so-obvious behaviors.
Like this initial setup in which there is already an available chunk of disk
right after the Windows partition, but that space is not big enough to
allocate the new system.

![A gap that is not big enough](space_maker_strategy_imgs/gap1.png)

In that case, the partitions are deleted in a rather weird order. First of all,
it would make sense to start deleting partitions that are next to the existing
gap, so that gap is enlarged. But instead of doing that, the gap is ignored and
partitions are deleted starting by the end of disk. Moreover, the position is
just a secondary criterion. Being Linux/Windows/other is more important, so the
partition at the end of the disk is left for later, resulting in this.

![Wrong reaction to the gap](space_maker_strategy_imgs/gap2.png)

Check the mentioned presentation for other examples. In general, if deleting
both Linux and "other" is allowed, it should try to delete partitions in the
order that guarantees more consecutive space with the minimal hurt, even if
that means interleaving the deletion of partitions of type Linux and type
"other".

### Resizing all first, deleting afterwards

Another problem of the current approach with a fixed order of operations is
that it always tries to resize Windows partitions before removing other
partitions. That leads to resizing partitions in cases in which it implies no
immediate gain.

Take this example layout which, based on several bug reports, we can say is
becoming more and more common in brand new computers.

![Typical modern Windows layout](space_maker_strategy_imgs/windows1.png)

The first two partitions are detected as Windows partitions (they both have the
files and structures needed to boot from them). If resizing the Windows2
partition is not enough, the SpaceMaker will try to resize Windows1 as second
step, just because resizing comes before deleting. Very often that second
resizing is pointless, the freed space is useless and a third step is necessary
afterwards anyways (deleting the "other" partition).

In some cases, resizing Windows1 could make sense at a later stage after having
deleted Windows2 (so the space freed by resizing Windows1 would actually be
useful). But doing it beforehand just because all the resizings come first and
all the deletions come afterwards (with no possibility of interleaving
operations) looks wrong and leads to wrong resize operations.

### Problems produced by the two resizing "attempts"

The current algorithm based on fixed steps forced the introduction of two
mutually exclusive steps for resizing Windows (the second one will only resize
Windows if the first step didn't do it). That's very confusing. Even with a
[long comment in the
code](https://github.com/yast/yast-storage-ng/blob/master/src/lib/y2storage/proposal/space_maker.rb#L228)
explaining how it works, there is still at least one open bug
([bsc#1057436](https://bugzilla.suse.com/show_bug.cgi?id=1057436)) about how
confusing it is to debug the process. That has leaded to several wrong diagnosis
in past bug reports. 

## Proposal #1: just a loop

It should be relatively easy to turn the current algorithm into something more
flexible and easier to understand, while still producing exactly the same
outcome in most situations. They key would be to change the current list of
predefined action into a simple loop like (ruby-like pseudocode ahead):

```
while !partitions_fit? do
  action = select_next_action # This could be resizing sda1, deleting sda3...
  perform(action)
end
```

With that, SpaceMaker would simply perform as first step whatever action
looks like the most promising (usually a resize if possible). If it's not enough,
it should then just re-evaluate which action is the most promising now. So actions
like resizing a Windows, deleting a Linux partition, deleting a Windows
partition and deleting another partition can be interleaved in any sequence that
makes sense.

While being more flexible when prioritizing some actions over others or for
introducing small exceptions in the process (as requested for IRST partitions or
the Raspberry Pi scenario), that algorithm can actually be used to implement
exactly the same behavior that the current SpaceMaker. It's enough to define
`select_next_action` in a way that mimics the currently hardcoded sequence.
That should be probably the first step before trying to introduce
exceptions and refinements. So, a simplified version using the same kind of
pseudocode would look like this.

```
def select_next_action
  if linux_partitions.any?
    action_to_delete_the_following_linux_partition
  else
    if windows_partitions.any?(&:not_resized_yet)
      action_to_resize_the_following_windows_partition
    else
      if other_partitions.any?
        action_to_delete_the_following_other_partition
      ...
      end
    ...
    end
  ...
  end
end
```

Starting from there, the next step could be to introduce the exceptions
requested in [fate#325885](https://fate.suse.com/325885) (IRST) and 
[fate#323484](https://fate.suse.com/323484) (Raspberry Pi).

In addition to the much improved flexibility to handle some cases, that small
twist should make easy to introduce and test different strategies. By clearly
separating the decision about what to do next, it would be easy to have
different versions of the so-called `select_next_action`. Maybe one that tries
to co-exist with any other Linux found vs one that tries to replace it. Or even
one specific for esoteric architectures like s390 and/or Raspberry Pi. The
possibility of having different strategies is nothing to be used in the short
term (or used at all), just an example on how a small change in the SpaceMaker
approach can open possibilities when compared to the current hardcoded sequence.

Last but not least, that change could also open future doors to having a
SpaceMaker that takes decision with a bigger level of depth. Considering not
only the outcome of the next action to perform but of the following 2 or 3.
Again, nothing to do in the short term since it sounds like a memory-hungry,
idea, but just another example on how a small twist to the current hardcoded
sequence can make things easier.
