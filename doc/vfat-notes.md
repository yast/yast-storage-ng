## VFAT and case-insensitve file names

When mounting a vfat file system the options `iocharset` and `codepage`
control the file name encoding.

For a discussion of vfat mount options see
[this](https://www.kernel.org/doc/Documentation/filesystems/vfat.txt)
kernel doc.

The current system defaults compiled into the kernel can be seen in

- `/proc/config.gz::CONFIG_FAT_DEFAULT_IOCHARSET` and
- `/proc/config.gz::CONFIG_FAT_DEFAULT_CODEPAGE`

`codepage` is used to convert long file names to legacy (DOS-like) 8.3 file
names. That's mostly irrelevant and users can stick to the default
(compiled-in) code page 437.

`iocharset` is used to convert from the vfat internally used utf16 to
whatever is needed by the current unix locale.

Ideally that is utf8.

Now here comes the catch: the kernel doesn't implement case conversion for
unicode **at all**. The kernel's `nls_strnicmp()` resp. `charset2lower()`
work byte-wise and won't do for utf8. That's why the `nls_utf8.ko` module doesn't
bother to provide any case conversion.

This means that `iocharset=utf8` will not have case-insensitive file names.
No matter what.

To still get the case-insensitivity wanted by vfat, there's a separate
code path triggered by the `utf8` option.

As it happens, the `utf8` option solves the case-insensitivity only partly
when it comes to non-ASCII chars.

Note that you can have both `iocharset=NOT_UTF8` **and** `utf8`. It is actually
**expected** that you do. The `iocharset` is used for the needed case-insensitve
comparision. From this follows that `iocharset=utf8,utf8` is doing you no
good.

See this shell session run on a vfat file system mounted with (only) `utf8`:

```sh
> touch ü
> touch Ü
> touch Ä
> touch ä
touch: cannot touch 'ä': File exists
> touch 1234567_ä
> touch 1234567_Ä
> touch 1234567_X
> touch 1234567_x
> ls
1234567_X 1234567_Ä  1234567_ä  Ä  ü
```

You can see that it works as long as you stick to ASCII. For other chars it
works 'somewhat'.

For example, starting with `ü` it sees that `Ü` is the same. But starting
with an uppercase letter like `Ä` it runs into a kernel bug when you try to
access `ä` (the `EEXIST` error in `touch` - in fact, any file open
triggers this).

File names with non-ASCII chars that don't fit into the 8.3 scheme are
completely case-sensitive.

The intention of the `utf8` options seems to have been to use `iocharset`
for case-insensitive comparison while still using utf8 encoding. But it is
not working this way.

A tentative explanation of the above behavior (including the bug) is that

1. the case-insensitive comparision of long file names does not work
2. instead, the match of `Ü` to `ü` occurs because `Ü` matches the existing valid 8.3 name `Ü`
  that has been created for `ü`
3. the bug happens because `ä` does not match `Ä` (and also not `Ä`'s 8.3
  name `Ä`) - and the kernel then tries to create a new `ä` but fails as the
  corresponding 8.3 name `Ä` already exists

Finally, note that `iocharset=NOT_UTF8` does have no issues and works fine.
But is mostly useless since utf8 locales are used everywhere.
