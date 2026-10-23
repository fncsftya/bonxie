--  The hosted backend's premium AI, which stands in for the local language model when it is
--  chosen in Settings. It is offered only while the `.env` file (see Dotenv) says `ENV=dev`;
--  `BACKEND` is the address it is at. The calls themselves are in the children, one to an
--  endpoint (see Premium.Sources).
package Premium is

   Default_Backend : constant String := "http://localhost:8080";

   function Available return Boolean;
   --  Whether premium AI can be chosen: `ENV` is `dev`.

   function Backend return String
     with Post => Backend'Result'Length > 0 and then Backend'Result (Backend'Result'Last) /= '/';
   --  Where the backend is: `BACKEND`, less any slash at the end; Default_Backend if it is not set.

   procedure Log (Words : String);
   --  Print Words to the console (standard error) as "[premium] Words", for a developer to see what the
   --  backend was asked and said; nothing unless Available.

end Premium;
