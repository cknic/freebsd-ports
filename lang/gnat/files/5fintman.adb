------------------------------------------------------------------------------
--                                                                          --
--                 GNU ADA RUNTIME LIBRARY (GNARL) COMPONENTS               --
--                                                                          --
--           S Y S T E M . I N T E R R U P T _ M A N A G E M E N T          --
--                                                                          --
--                                  B o d y                                 --
--                         (Version for new GNARL)                          --
--                                                                          --
--                             $Revision: 1.3 $                            --
--                                                                          --
--   Copyright (C) 1991,1992,1993,1994,1995,1996 Florida State University   --
--                                                                          --
-- GNARL is free software; you can  redistribute it  and/or modify it under --
-- terms of the  GNU General Public License as published  by the Free Soft- --
-- ware  Foundation;  either version 2,  or (at your option) any later ver- --
-- sion. GNARL is distributed in the hope that it will be useful, but WITH- --
-- OUT ANY WARRANTY;  without even the  implied warranty of MERCHANTABILITY --
-- or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License --
-- for  more details.  You should have  received  a copy of the GNU General --
-- Public License  distributed with GNARL; see file COPYING.  If not, write --
-- to  the Free Software Foundation,  59 Temple Place - Suite 330,  Boston, --
-- MA 02111-1307, USA.                                                      --
--                                                                          --
-- As a special exception,  if other files  instantiate  generics from this --
-- unit, or you link  this unit with other files  to produce an executable, --
-- this  unit  does not  by itself cause  the resulting  executable  to  be --
-- covered  by the  GNU  General  Public  License.  This exception does not --
-- however invalidate  any other reasons why  the executable file  might be --
-- covered by the  GNU Public License.                                      --
--                                                                          --
-- GNARL was developed by the GNARL team at Florida State University. It is --
-- now maintained by Ada Core Technologies Inc. in cooperation with Florida --
-- State University (http://www.gnat.com).                                  --
--                                                                          --
------------------------------------------------------------------------------

--  This is the FreeBSD PTHREADS version of this package

--  This is only a first approximation.
--  It should be autogenerated by the m4 macro processor.
--  Contributed by Peter Burwood (gnat@arcangel.dircon.co.uk).

--  This file performs the system-dependent translation between machine
--  exceptions and the Ada exceptions, if any, that should be raised when
--  they occur.  This version works for FreeBSD.  Contributed by
--  Daniel M. Eischen (eischen@vigrid.com).

--  PLEASE DO NOT add any dependences on other packages.
--  This package is designed to work with or without tasking support.

--  See the other warnings in the package specification before making
--  any modifications to this file.

--  Make a careful study of all signals available under the OS,
--  to see which need to be reserved, kept always unmasked,
--  or kept always unmasked.
--  Be on the lookout for special signals that
--  may be used by the thread library.

with Interfaces.C;
--  used for int and other types

with System.OS_Interface;
--  used for various Constants, Signal and types

package body System.Interrupt_Management is

   use Interfaces.C;
   use System.OS_Interface;

   type Interrupt_List is array (Interrupt_ID range <>) of Interrupt_ID;
   Exception_Interrupts : constant Interrupt_List :=
     (SIGFPE, SIGILL, SIGSEGV, SIGBUS);

   Unreserve_All_Interrupts : Interfaces.C.int;
   pragma Import
     (C, Unreserve_All_Interrupts, "__gl_unreserve_all_interrupts");

   ----------------------
   -- Notify_Exception --
   ----------------------

   Signal_Mask : aliased sigset_t;
   --  The set of signals handled by Notify_Exception

   --  This function identifies the Ada exception to be raised using
   --  the information when the system received a synchronous signal.
   --  Since this function is machine and OS dependent, different code
   --  has to be provided for different target.

   --  Language specs say signal handlers take exactly one arg, even
   --  though FreeBSD actually supplies three.  Ugh!

   procedure Notify_Exception
     (signo   : Signal;
      code    : Interfaces.C.int;
      context : access struct_sigcontext);

   procedure Notify_Exception
     (signo   : Signal;
      code    : Interfaces.C.int;
      context : access struct_sigcontext) is
      Result : Interfaces.C.int;
   begin
      --  With the __builtin_longjmp, the signal mask is not restored, so we
      --  need to restore it explicitely.

      Result := pthread_sigmask (SIG_UNBLOCK, Signal_Mask'Access, null);
      pragma Assert (Result = 0);

      --  Check that treatment of exception propagation here
      --  is consistent with treatment of the abort signal in
      --  System.Task_Primitives.Operations.

      case signo is
         when SIGFPE =>
            raise Constraint_Error;
         when SIGILL =>
            raise Constraint_Error;
         when SIGSEGV =>
            raise Storage_Error;
         when SIGBUS =>
            raise Storage_Error;
         when others =>
            pragma Assert (False);
            null;
      end case;
   end Notify_Exception;

   ---------------------------
   -- Initialize_Interrupts --
   ---------------------------

   --  Nothing needs to be done on this platform.

   procedure Initialize_Interrupts is
   begin
      null;
   end Initialize_Interrupts;

begin
   declare
      act     : aliased struct_sigaction;
      old_act : aliased struct_sigaction;
      Result  : Interfaces.C.int;

   begin

      Abort_Task_Interrupt := SIGADAABORT;
      --  Change this if you want to use another signal for task abort.
      --  SIGTERM might be a good one.

      act.sa_handler := Notify_Exception'Address;

      act.sa_flags := 0;

      --  On some targets, we set sa_flags to SA_NODEFER so that during the
      --  handler execution we do not change the Signal_Mask to be masked for
      --  the Signal.
      --  This is a temporary fix to the problem that the Signal_Mask is
      --  not restored after the exception (longjmp) from the handler.
      --  The right fix should be made in sigsetjmp so that we save
      --  the Signal_Set and restore it after a longjmp.
      --  Since SA_NODEFER is obsolete, instead we reset explicitely
      --  the mask in the exception handler.

      Result := sigemptyset (Signal_Mask'Access);
      pragma Assert (Result = 0);

      for I in Exception_Interrupts'Range loop
         Result :=
           sigaddset
             (Signal_Mask'Access, Signal (Exception_Interrupts (I)));
         pragma Assert (Result = 0);
      end loop;

      act.sa_mask := Signal_Mask;

      for I in Exception_Interrupts'Range loop
         Keep_Unmasked (Exception_Interrupts (I)) := True;
         Result :=
           sigaction
             (Signal (Exception_Interrupts (I)), act'Unchecked_Access,
              old_act'Unchecked_Access);
         pragma Assert (Result = 0);
      end loop;

      Keep_Unmasked (Abort_Task_Interrupt) := True;

      --  By keeping SIGINT unmasked, allow the user to do a Ctrl-C, but in the
      --  same time, disable the ability of handling this signal
      --  via Ada.Interrupts.
      --  The pragma Unreserve_All_Interrupts let the user the ability to
      --  change this behavior.

      if Unreserve_All_Interrupts = 0 then
         Keep_Unmasked (SIGINT) := True;
      end if;

      for I in Unmasked'Range loop
         Keep_Unmasked (Interrupt_ID (Unmasked (I))) := True;
      end loop;

      Reserve := Keep_Unmasked or Keep_Masked;

      for I in Reserved'Range loop
         Reserve (Interrupt_ID (Reserved (I))) := True;
      end loop;

      Reserve (0) := True;
      --  We do not have Signal 0 in reality. We just use this value
      --  to identify non-existent signals (see s-intnam.ads). Therefore,
      --  Signal 0 should not be used in all signal related operations hence
      --  mark it as reserved.
   end;
end System.Interrupt_Management;
