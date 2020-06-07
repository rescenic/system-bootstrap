#! /usr/bin/env python3
# -*- coding: utf-8 -*-

# demo.py --- Demonstration program and cheap test suite for pythondialog

import sys, os, locale, stat, time, getopt, subprocess, traceback, textwrap
import pprint
import dialog
from dialog import DialogBackendVersion


class BaseDialog:
    """Wrapper class for dialog.Dialog.
    """

    def __init__(self, Dialog_instance):
        self.dlg = Dialog_instance

    def check_exit_request(self, code, ignore_Cancel=False):
        if code == self.CANCEL and ignore_Cancel:
            # Ignore the Cancel button, i.e., don't interpret it as an exit
            # request; instead, let the caller handle CANCEL himself.
            return True

        if code in (self.CANCEL, self.ESC):
            button_name = {self.CANCEL: "Cancel", self.ESC: "Escape"}
            msg = (
                "You pressed {0} in the last dialog box. Do you want "
                "to exit this demo?".format(button_name[code])
            )
            if self.dlg.yesno(msg) == self.OK:
                sys.exit(0)
            else:  # "No" button chosen, or ESC pressed
                return False  # in the "confirm quit" dialog
        else:
            return True

    def widget_loop(self, method):
        """Decorator to handle eventual exit requests from a Dialog widget.
        """

        def wrapper(*args, **kwargs):
            while True:
                res = method(*args, **kwargs)

                if hasattr(method, "retval_is_code") and getattr(
                    method, "retval_is_code"
                ):
                    code = res
                else:
                    code = res[0]

                if self.check_exit_request(code):
                    break
            return res

        return wrapper

    def __getattr__(self, name):
        obj = getattr(self.dlg, name)
        if hasattr(obj, "is_widget") and getattr(obj, "is_widget"):
            return self.widget_loop(obj)
        else:
            return obj

    def clear_screen(self):
        program = "clear"

        try:
            p = subprocess.Popen(
                [program], shell=False, stdout=None, stderr=None, close_fds=True
            )
            retcode = p.wait()
        except os.error as e:
            self.msgbox(
                "Unable to execute program '%s': %s." % (program, e.strerror),
                title="Error",
            )
            return False

        if retcode > 0:
            msg = "Program %s returned exit status %d." % (program, retcode)
        elif retcode < 0:
            msg = "Program %s was terminated by signal %d." % (program, -retcode)
        else:
            return True

        self.msgbox(msg)
        return False

    def _yes_no(self, *args, **kwargs):
        """Convenience wrapper around dialog.Dialog.yesno().
        """
        while True:
            code = self.dlg.yesno(*args, **kwargs)
            # If code == self.CANCEL, it means the "No" button was chosen;
            # don't interpret this as a wish to quit the program!
            if self.check_exit_request(code, ignore_Cancel=True):
                break

        return code

    def yes_no(self, *args, **kwargs):
        """Convenience wrapper around dialog.Dialog.yesno().
        """
        return self._yes_no(*args, **kwargs) == self.dlg.OK

    def yes_no_help(self, *args, **kwargs):
        """Convenience wrapper around dialog.Dialog.yesno().
        """
        kwargs["help_button"] = True
        code = self._yes_no(*args, **kwargs)
        d = {
            self.dlg.OK: "yes",
            self.dlg.CANCEL: "no",
            self.dlg.EXTRA: "extra",
            self.dlg.HELP: "help",
        }

        return d[code]


class DialogContextManager:
    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False
