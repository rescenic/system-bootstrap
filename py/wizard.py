#! /usr/bin/env python3
# -*- coding: utf-8 -*-

# wizard.py --- A dialog program show user options of system-bootstrap

import getopt
import locale
import os
import pprint
import stat
import subprocess
import sys
import textwrap
import time
import traceback
from textwrap import dedent, indent

import dialog
from arch_installer import ArchInstaller
from base import BaseDialog, DialogContextManager
from dialog import DialogBackendVersion

progname = os.path.basename(sys.argv[0])
progversion = "0.0.1"
version_blurb = """ \
This is free software; see the source for copying conditions. \
There is NO warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE."""

default_debug_filename = "wizard.debug"

usage = """Usage: {progname} [option ...]
Program to allow user to perform various operations regarding Arch Linux.

Options:
      --debug                  enable logging of all dialog command lines
      --debug-file=FILE        where to write debug information (default:
                               {debug_file} in the current directory)
  -E, --debug-expand-file-opt  expand the '--file' options in the debug file
                               generated by '--debug'
      --help                   display this message and exit
      --version                output version information and exit""".format(
    progname=progname, debug_file=default_debug_filename
)

params = {}

d = None

tw = textwrap.TextWrapper(width=78, break_long_words=False, break_on_hyphens=True)


class Wizard:
    def __init__(self):
        global d
        self.Dialog_instance = dialog.Dialog(dialog="dialog")
        d = BaseDialog(self.Dialog_instance)
        backtitle = "Arch Wizard"
        d.set_background_title(backtitle)
        self.max_lines, self.max_cols = d.maxsize(backtitle=backtitle)
        self.min_rows, self.min_cols = 24, 80
        self.wizard_context = self.setup_debug()
        (
            self.term_rows,
            self.term_cols,
            self.backend_version,
        ) = self.get_term_size_and_backend_version()

    def setup_debug(self):
        if params["debug"]:
            debug_file = open(params["debug_filename"], "w")
            d.setup_debug(
                True, file=debug_file, expand_file_opt=params["debug_expand_file_opt"]
            )
            return debug_file
        else:
            return DialogContextManager()

    def get_term_size_and_backend_version(self):
        backend_version = d.cached_backend_version
        if not backend_version:
            print(
                tw.fill(
                    "Unable to retrieve the version of the dialog-like backend. "
                    "Not running cdialog?"
                )
                + "\nPress Enter to continue.",
                file=sys.stderr,
            )
            input()

        term_rows, term_cols = d.maxsize(use_persistent_args=False)
        if term_rows < self.min_rows or term_cols < self.min_cols:
            print(
                tw.fill(
                    dedent(
                        """\
             Your terminal has less than {0} rows or less than {1} columns;
             you may experience problems with the demo. You have been warned.""".format(
                            self.min_rows, self.min_cols
                        )
                    )
                )
                + "\nPress Enter to continue."
            )
            input()

        return (term_rows, term_cols, backend_version)

    def run(self):
        with self.wizard_context:
            self.decide_fate()

    def decide_fate(self):
        d.msgbox(
            """
                Hello, and welcome to the System-Boostrap {pydlg_version}.

                This script is being run by a Python interpreter identified as follows: {py_version}
            """.format(
                pydlg_version=dialog.__version__, py_version=indent(sys.version, "  "),
            ),
            width=60,
            height=17,
        )
        self.get_fate()
        d.clear_screen()

    def get_fate(self):
        text = """Choose wisely."""
        while True:
            code, tag = d.menu(
                text,
                height=15,
                width=70,
                choices=[
                    (
                        "Install Arch Linux",
                        "Installs Arch Linux using user input.",
                        "Installs a fresh Arch Linux system.",
                    ),
                    (
                        "Create Arch ISO",
                        "A disk preloaded with this wizard.",
                        "Creates a bootable ISO of Arch preloaded with dependencies needed to use this wizard.",
                    ),
                    (
                        "Install dotfiles",
                        "Have vlad's or your own dotfiles installed.",
                        "Installs dotfiles for a given user.",
                    ),
                ],
                title="Choose your destiny...",
                help_button=True,
                item_help=True,
                help_tags=True,
            )

            if code == "help":
                d.msgbox(
                    "You asked for help concerning the item identified by "
                    "tag {0!r}.".format(tag),
                    height=8,
                    width=40,
                )
            else:
                break
        while True:
            reply = d.yes_no_help(
                "\nYou have chosen " "{0!r}, continue?".format(tag),
                yes_label="Yes",
                no_label="No",
                help_label="Please help me!",
                height=10,
                width=60,
                title="An Important Question",
            )
            if reply == "yes":
                if tag == "Install Arch Linux":
                    installer = ArchInstaller()
                    installer.run()
                return True
            elif reply == "no":
                self.get_fate()
            elif reply == "help":
                d.msgbox(
                    """\
I can hear your cry for help, and would really like to help you. However, I \
am afraid there is not much I can do for you here; you will have to decide \
for yourself on this matter.

Keep in mind that you can always rely on me. \
You have all my support, be brave!""",
                    height=15,
                    width=60,
                    title="From Your Faithful Servant",
                )
            else:
                assert False, "Unexpected reply from WizardDialog.yes_no_help(): " + repr(
                    reply
                )


def process_command_line():
    global params

    try:
        opts, args = getopt.getopt(
            sys.argv[1:],
            "ftE",
            ["debug", "debug-file=", "debug-expand-file-opt", "help", "version",],
        )
    except getopt.GetoptError:
        print(usage, file=sys.stderr)
        return ("exit", 1)

    for option, value in opts:
        if option == "--help":
            print(usage)
            return ("exit", 0)
        elif option == "--version":
            print("%s %s\n%s" % (progname, progversion, version_blurb))
            return ("exit", 0)

    # Now, require a correct invocation.
    if len(args) != 0:
        print(usage, file=sys.stderr)
        return ("exit", 1)

    # Default values for parameters
    params = {
        "debug": False,
        "debug_filename": default_debug_filename,
        "debug_expand_file_opt": False,
    }

    root_dir = os.sep  # This is OK for Unix-like systems
    params["home_dir"] = os.getenv("HOME", root_dir)

    # General option processing
    for option, value in opts:
        if option == "--debug":
            params["debug"] = True
        elif option == "--debug-file":
            params["debug_filename"] = value
        elif option in ("-E", "--debug-expand-file-opt"):
            params["debug_expand_file_opt"] = True
        else:
            assert False, (
                "Unexpected option received from the " "getopt module: '%s'" % option
            )

    return ("continue", None)


def main():
    locale.setlocale(locale.LC_ALL, "")

    what_to_do, code = process_command_line()
    if what_to_do == "exit":
        sys.exit(code)

    try:
        app = Wizard()
        app.run()
    except dialog.error as exc_instance:
        if not isinstance(exc_instance, dialog.PythonDialogErrorBeforeExecInChildProcess):
            print(traceback.format_exc(), file=sys.stderr)

        print(
            "Error (see above for a traceback):\n\n{0}".format(exc_instance),
            file=sys.stderr,
        )
        sys.exit(1)

    sys.exit(0)


if __name__ == "__main__":
    main()
