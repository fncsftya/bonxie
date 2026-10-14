private with Ada.Finalization;
private with System;

--  A model, loaded, and one stream through it: open it, begin a stream,
--  Feed it audio as it comes, read the text so far (Text) after each feed,
--  and Finalize at the end for the rest. Several sessions may be open at
--  once, one to a task; a session is for one task at a time. Open, Feed and
--  Finalize do the model's work, so they take a while and are not for the
--  main thread.
package Transcribe.Sessions is

   type Session is limited private;

   function Is_Open (Item : Session) return Boolean;

   function Is_Streaming (Item : Session) return Boolean
     with Pre => Is_Open (Item);
   --  Whether Begin_Stream has been called, and the stream is neither
   --  finished nor failed.

   procedure Open
     (Item    : in out Session;
      Path    : String;
      Ok      : out Boolean;
      Message : out String;
      Last    : out Natural)
     with Pre  => not Is_Open (Item) and then Message'First = 1,
          Post => Ok = Is_Open (Item);
   --  Load the model in the file. On failure Message (1 .. Last) says why
   --  (no file, not a model).

   procedure Begin_Stream
     (Item    : in out Session;
      Ok      : out Boolean;
      Message : out String;
      Last    : out Natural)
     with Pre  => Is_Open (Item) and then Message'First = 1,
          Post => Ok = Is_Streaming (Item);
   --  Start a stream, throwing away any earlier one. A model that cannot
   --  stream fails here.

   procedure Feed
     (Item    : in out Session;
      Audio   : Samples;
      Changed : out Boolean;
      Ok      : out Boolean;
      Message : out String;
      Last    : out Natural)
     with Pre => Is_Streaming (Item) and then Message'First = 1;
   --  Give the stream more audio. Changed says the text is not as it was.
   --  If not Ok the stream has failed.

   procedure Finalize_Stream
     (Item    : in out Session;
      Ok      : out Boolean;
      Message : out String;
      Last    : out Natural)
     with Pre  => Is_Streaming (Item) and then Message'First = 1,
          Post => not Is_Streaming (Item);
   --  There is no more audio: settle what is left of the text.

   procedure Text
     (Item      : Session;
      Into      : out String;
      Last      : out Natural;
      Truncated : out Boolean)
     with Pre => Is_Open (Item) and then Into'First = 1;
   --  What the stream says so far, committed words and then the tentative
   --  ones, which a later Feed may change (Into (1 .. Last); less of it
   --  if it does not fit, when Truncated). Empty if no stream was begun.

   procedure Close (Item : in out Session)
     with Post => not Is_Open (Item);
   --  Free the model. Done anyway when the session goes away.

private

   type Session is new Ada.Finalization.Limited_Controlled with record
      Handle    : System.Address := System.Null_Address;
      Streaming : Boolean := False;
   end record;

   overriding procedure Finalize (Item : in out Session);

end Transcribe.Sessions;
