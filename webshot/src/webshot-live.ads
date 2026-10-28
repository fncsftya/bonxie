with System;

--  A live web view in a window (macOS only): unlike a job of Webshot, it is for
--  a person to use, and it keeps what the pages tell it, so that they stay
--  logged in. It is a native view laid over the window's content, so it is
--  drawn above everything the program draws there: Hide it while something
--  of the program's is to be seen over it. All of it is for the main thread.

package Webshot.Live is

   use type System.Address;

   procedure Attach (Window : System.Address)
   with Pre => Window /= System.Null_Address;
   --  Add the view to a window, which is the NSWindow of SDL3.Windows.Native_Handle.
   --  It is hidden and has no size until Place is called.

   procedure Detach;
   --  Take it away.

   function Attached return Boolean;

   procedure Place (X, Y, Wide, High : Float)
   with Pre => Attached and then Wide >= 0.0 and then High >= 0.0;
   --  Where the view is, in points from the window content's top left.

   procedure Show (Visible : Boolean)
   with Pre => Attached;

   procedure Load (URL : String)
   with Pre => Attached;

   procedure Focus (Page : Boolean)
   with Pre => Attached;
   --  Give the keyboard to the page, or take it back for the program.

   function Has_Focus return Boolean
   with Pre => Attached;

   procedure Keep (Letter : Character; Number : Positive)
   with Pre => Number <= 8;
   --  Keep Command with Letter for the program: while the page has the keyboard it is not the page's, but
   --  is said by Shortcut as Number. At most 8.

   function Shortcut return Natural;
   --  The number of a kept shortcut pressed since this was last called; 0 if none.

   procedure Go_Back
   with Pre => Attached;

   procedure Go_Forward
   with Pre => Attached;

   procedure Reload
   with Pre => Attached;

   function Can_Go_Back return Boolean
   with Pre => Attached;

   function Can_Go_Forward return Boolean
   with Pre => Attached;

   function Loading return Boolean
   with Pre => Attached;

   function Load_Progress return Float
   with Pre => Attached, Post => Load_Progress'Result in 0.0 .. 1.0;

   function Title return String
   with Pre => Attached;
   --  Empty if the page has none yet.

   function Address return String
   with Pre => Attached;
   --  The page's, as it now is (a redirect or a click changes it).

   function Theme_Colour return Integer
   with Pre => Attached, Post => Theme_Colour'Result in -1 .. 16#FFFFFF#;
   --  The colour the page gives itself (its theme-color), as 16#RRGGBB#; -1 if it gives none (or not yet).

   type Capture_States is (Idle, Working, Done, Failed);

   procedure Capture (File : String)
   with Pre => Attached and then Capture_State /= Working, Post => Capture_State = Working;
   --  Begin to take a picture of the whole page as it now is, with whatever the person has done to it, to be
   --  written as File (in a folder that exists): as Webshot does a page, in strips one under another, the first
   --  File and the rest beside it (see Pomarine.Strips), none more than a texture can be tall. The view is
   --  hidden for a moment as it is taken.

   function Capture_State return Capture_States;

   function Capture_Strips return Natural;
   --  How many pictures are written so far.

   function Capture_Title return String;
   --  The page's title when the capture began.

   function Capture_Message return String;
   --  Why a Failed capture was.

   procedure Capture_Reset;
   --  Forget how a capture ended: Idle (not a Working one, which goes on).

end Webshot.Live;
