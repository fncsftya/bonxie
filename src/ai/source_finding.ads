with Ada.Strings.Bounded;

--  What is asked of a language model to find sources for a piece of writing,
--  and how what it replies is read. There are two asks, each with a system
--  prompt of its own: from the text, a few queries for a web search; and,
--  for each page that was found, how good a source of the text it is. The
--  model is told to reply with nothing but a JSON object (see the schemas),
--  and the reply is parsed here, as it is not a model's way to be exact; a
--  reply that does not parse is the caller's to ask for again. (The model is
--  Gemma 4, which is asked not to think aloud: the replies are still read
--  with some patience, as the prompts leave room for a model that does.)

--  A third ask, of each page, is whether something covers it (a cookie banner),
--  and which button closes it: the model cannot see, so it is given the words
--  read from a picture of the top of the page.
package Source_Finding is

   Max_Tries : constant := 3;
   --  How many times the model is asked each, before the work is given up.

   Max_Text : constant := 6_000;
   --  Bytes of the writer's text, and of a page's, that the model is given:
   --  more is cut off.

   --  The queries

   Max_Queries : constant := 3;

   Max_Query : constant := 200;
   --  Bytes of a query.

   package Query_Texts is new Ada.Strings.Bounded.Generic_Bounded_Length (Max_Query);

   type Query_Array is array (1 .. Max_Queries) of Query_Texts.Bounded_String;

   type Query_List is record
      Count : Natural range 0 .. Max_Queries := 0;
      Items : Query_Array;
   end record;

   Query_Tokens : constant := 8_192;
   --  The most the model may make, thoughts and reply, to write the queries: a
   --  model that thinks aloud in its reply needs room for that and the object.

   function Query_System_Prompt return String
     with Post => Query_System_Prompt'Result'Length > 0;
   --  What the model is told it is for, with the schema of its reply in it.

   function Query_Prompt (Text : String) return String
     with Pre  => Text'Length > 0,
          Post => Query_Prompt'Result'Length > 0;
   --  The writer's text (the first Max_Text bytes of it), to write queries for.

   procedure Parse_Queries
     (Reply  : String;
      Result : out Query_List;
      Valid  : out Boolean)
     with Post => (if Valid then Result.Count > 0 else Result.Count = 0);
   --  The queries the model replied with: tidied, cut to Max_Query, and, beyond
   --  Max_Queries, left out; those that are blank or given already (whatever
   --  the case) are left out too. Valid is False, and Result empty, if there
   --  is no JSON object in Reply that fits the schema, or no query in it.

   --  The notice over a page

   Max_Button : constant := 60;
   --  Bytes of the words of a button.

   package Button_Texts is new Ada.Strings.Bounded.Generic_Bounded_Length (Max_Button);

   Banner_Tokens : constant := 8_192;
   --  The most the model may make to say what covers a page.

   Max_Presses : constant := 2;
   --  How many buttons are pressed on a page, as one notice may lead to another.

   function Banner_System_Prompt return String
     with Post => Banner_System_Prompt'Result'Length > 0;
   --  What the model is told it is for, with the schema of its reply in it.

   function Banner_Prompt (Words : String; Refused : String := "") return String
     with Post => Banner_Prompt'Result'Length > 0;
   --  The words read from the top of a page (the first Max_Text bytes of them),
   --  to say what covers it. If a button was named that could not be pressed
   --  (there was none by that name, or it was one that must not be: see
   --  webshot_wk.m), Refused is its words, and the model is told, to choose another.

   procedure Parse_Banner
     (Reply   : String;
      Covered : out Boolean;
      Button  : out Button_Texts.Bounded_String;
      Valid   : out Boolean)
     with Post => (if Covered then Valid and then Button_Texts.Length (Button) > 0);
   --  Whether the model said something covers the page, and the words of the
   --  button that closes it (tidied and cut to Max_Button). A page said to be
   --  covered with no button to press is not covered, as far as is of use. Valid
   --  is False if there is no JSON object in Reply that fits the schema.

   --  The judging of a page

   Max_Reason : constant := 240;
   --  Bytes of the reason given for a score.

   package Reason_Texts is new Ada.Strings.Bounded.Generic_Bounded_Length (Max_Reason);

   subtype Mark is Natural range 0 .. 10;

   type Evaluation is record
      Relevance : Mark := 0;
      --  How much the page is about what the text is.
      Support   : Mark := 0;
      --  How much it has to back up or inform what the text says.
      Quality   : Mark := 0;
      --  How far it can be trusted, and how much there is to it.
      Reason    : Reason_Texts.Bounded_String;
   end record;

   function Percent (Of_Evaluation : Evaluation) return Natural
     with Post => Percent'Result <= 100;
   --  The marks as a whole number of percents of the most they can be,
   --  rounded.

   Pass_Percent : constant := 70;
   --  A page is a source worth keeping if it scores this much, or more.

   function Passes (Of_Evaluation : Evaluation) return Boolean
     is (Percent (Of_Evaluation) >= Pass_Percent);

   Evaluation_Tokens : constant := 8_192;
   --  The most the model may make to judge a page, as for the queries.

   function Evaluation_System_Prompt return String
     with Post => Evaluation_System_Prompt'Result'Length > 0;
   --  What the model is told it is for, with the schema of its reply in it.

   function Evaluation_Prompt (Text, Title, Address, Page : String) return String
     with Pre  => Text'Length > 0,
          Post => Evaluation_Prompt'Result'Length > 0;
   --  The writer's text, and a page to judge as a source of it: its title,
   --  its address, and the words read from its picture. Each is cut to a
   --  size that is of use.

   procedure Parse_Evaluation
     (Reply  : String;
      Result : out Evaluation;
      Valid  : out Boolean);
   --  The marks the model replied with and its reason (tidied, cut to
   --  Max_Reason, and left empty if it gave none). Valid is False, and Result
   --  all zero, if there is no JSON object in Reply that fits the schema, or
   --  a mark in it is not a whole number from 0 to 10.

private

   LF : constant Character := Character'Val (10);

   Query_Schema : constant String :=
     "{" & LF
     & "  ""type"": ""object""," & LF
     & "  ""properties"": {" & LF
     & "    ""queries"": {" & LF
     & "      ""type"": ""array""," & LF
     & "      ""minItems"": 1," & LF
     & "      ""maxItems"": 3," & LF
     & "      ""items"": { ""type"": ""string"", ""minLength"": 3, ""maxLength"": 200 }" & LF
     & "    }" & LF
     & "  }," & LF
     & "  ""required"": [""queries""]," & LF
     & "  ""additionalProperties"": false" & LF
     & "}";

   Query_Guidelines : constant String :=
     "You help a writer find sources. You are given a passage they are writing. Work out what "
     & "it is about and the claims, facts and ideas in it that a reader would want evidence for, "
     & "and write between 1 and 3 queries for a web search engine that would find pages to "
     & "cite: research, reference works, reporting and official sources." & LF & LF
     & "Guidelines:" & LF
     & "- Write each query as keywords, as a person types into a search engine: between 3 and "
     & "8 words, with no quotation marks, operators or punctuation." & LF
     & "- Name the specific subject: the people, places, works, events, methods and terms the "
     & "passage names, rather than words that could be about anything." & LF
     & "- If the passage has one focus, write one query or two; if it has several distinct "
     & "topics, one query for each, up to 3. Never give two queries that would find the same "
     & "pages." & LF
     & "- Do not search for the writer's opinions, plans or style, nor for the passage "
     & "itself." & LF
     & "- Write in the language of the passage." & LF;

   Query_Closing : constant String :=
     LF & "Do not think aloud or explain. Your whole reply is a single JSON object, starting with an "
     & "opening brace, that conforms to this JSON Schema: no words before or after it, and no "
     & "Markdown code fences." & LF & LF;

   Query_Example : constant String :=
     LF & LF & "For example:" & LF
     & "{""queries"": [""james webb telescope first images galaxy clusters"", "
     & """jwst infrared detectors how they work""]}";

   Banner_Schema : constant String :=
     "{" & LF
     & "  ""type"": ""object""," & LF
     & "  ""properties"": {" & LF
     & "    ""covered"": { ""type"": ""boolean"" }," & LF
     & "    ""button"": { ""type"": ""string"", ""maxLength"": 60 }" & LF
     & "  }," & LF
     & "  ""required"": [""covered"", ""button""]," & LF
     & "  ""additionalProperties"": false" & LF
     & "}";

   Banner_Guidelines : constant String :=
     "You help a program read web pages. You are given the words that were read, from a picture of "
     & "the top of a web page as it first appears, in reading order, a line to a line. Say whether "
     & "something covers the page, or asks for an answer before the page can be read: a cookie or "
     & "privacy consent banner or dialog, an age check, a pop-up asking to subscribe or to join a "
     & "newsletter or to install an app, a notice about an ad blocker, or a prompt to sign in." & LF & LF
     & "Guidelines:" & LF
     & "- If something does, give the exact words on the one button or link that closes it, as they "
     & "are written in the text: a few words, no more, and not a sentence of the notice." & LF
     & "- Cookies are to be accepted: the page is read in a window that keeps nothing. For a cookie "
     & "notice, choose the button that accepts (Accept all, Allow all, Agree, I agree, OK, Got it); "
     & "else one that closes the notice (Close, Continue, Not now, a cross); and only if there is "
     & "neither, one that rejects or keeps to what is necessary. For any other notice, the button that "
     & "closes it or says no thanks." & LF
     & "- Never choose a button that takes the reader away or costs something (Sign in, Subscribe, "
     & "Buy, Manage preferences, Settings), nor a link that is part of the page's own text. A button "
     & "that offers to subscribe or pay is a purchase, not a rejection, whatever else its label says: "
     & "Reject all and subscribe for a price is not the way to reject." & LF
     & "- Give the label in full, as it is written on the button, not the start of it." & LF
     & "- If nothing covers the page, covered is false and button is empty. A page that only has a "
     & "menu, a header, an advertisement or a footer is not covered." & LF;

   Banner_Closing : constant String :=
     LF & "Do not think aloud or explain. Your whole reply is a single JSON object, starting with an "
     & "opening brace, that conforms to this JSON Schema: no words before or after it, and no "
     & "Markdown code fences." & LF & LF;

   Banner_Example : constant String :=
     LF & LF & "For example:" & LF
     & "{""covered"": true, ""button"": ""Accept all""}" & LF
     & "or, if nothing covers the page:" & LF
     & "{""covered"": false, ""button"": """"}";

   function Banner_System_Prompt return String is
     (Banner_Guidelines & Banner_Closing & Banner_Schema & Banner_Example);

   Evaluation_Schema : constant String :=
     "{" & LF
     & "  ""type"": ""object""," & LF
     & "  ""properties"": {" & LF
     & "    ""relevance"": { ""type"": ""integer"", ""minimum"": 0, ""maximum"": 10 }," & LF
     & "    ""support"": { ""type"": ""integer"", ""minimum"": 0, ""maximum"": 10 }," & LF
     & "    ""quality"": { ""type"": ""integer"", ""minimum"": 0, ""maximum"": 10 }," & LF
     & "    ""reason"": { ""type"": ""string"", ""maxLength"": 240 }" & LF
     & "  }," & LF
     & "  ""required"": [""relevance"", ""support"", ""quality"", ""reason""]," & LF
     & "  ""additionalProperties"": false" & LF
     & "}";

   Evaluation_Guidelines : constant String :=
     "You judge whether a web page is a good source for a passage that a writer is working on. "
     & "You are given the passage, and then the page: its title, its address and its text, "
     & "which was read from a picture of the page and so may have menus, advertisements and "
     & "other clutter among it. Give three marks, each a whole number from 0 to 10:" & LF
     & "- relevance: how closely the page is about what the passage is about. 10 is the same "
     & "subject in the same terms; 0 is another subject." & LF
     & "- support: how much the page has that a writer could use to back up or inform the "
     & "passage's claims: facts, data, findings, quotations or explanation. 0 if it has none." & LF
     & "- quality: how far the page can be trusted as a source, and how much there is to it. "
     & "A page of original research, an official or reference site, or careful reporting "
     & "scores high; a thin page, a sales or promotional page, a forum thread, a list made to "
     & "attract clicks, or a page with little of its own scores low." & LF & LF
     & "Guidelines:" & LF
     & "- Be strict. A mark of 8 or more is for a page that a careful writer would be glad to "
     & "cite for this passage." & LF
     & "- A page with no real content, as an error, a login, a cookie notice or a challenge to "
     & "show you are a person, scores 0 on all three." & LF
     & "- Judge only from what you are given. Do not suppose a page says what its title "
     & "suggests." & LF
     & "- Give a reason in one short sentence, in the language of the passage: what the page "
     & "offers, or why it does not suit." & LF;

   Evaluation_Closing : constant String :=
     LF & "Do not think aloud or explain. Your whole reply is a single JSON object, starting with an "
     & "opening brace, that conforms to this JSON Schema: no words before or after it, and no "
     & "Markdown code fences. Judge quickly, from the first part of the page, the reason being "
     & "one sentence." & LF & LF;

   Evaluation_Example : constant String :=
     LF & LF & "For example:" & LF
     & "{""relevance"": 9, ""support"": 8, ""quality"": 9, ""reason"": ""A review of the "
     & "evidence on the passage's subject, by a university.""}";

   function Query_System_Prompt return String is
     (Query_Guidelines & Query_Closing & Query_Schema & Query_Example);

   function Evaluation_System_Prompt return String is
     (Evaluation_Guidelines & Evaluation_Closing & Evaluation_Schema & Evaluation_Example);

end Source_Finding;
