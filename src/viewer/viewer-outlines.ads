with Projects.Sections;

--  The outline view: a form of the project's title and description at the
--  left, and at the right the titles of its sections, as blocks that are
--  dragged, or moved up and down, into the order they are to come in, and
--  removed. Everything is kept as it is typed or done.
private package Viewer.Outlines is

   function Section_Count (Item : Session) return Natural
     with Pre => Screen (Item) = Project;

   function Section_Title (Item : Session; Which : Positive) return String
     with Pre => Screen (Item) = Project and then Which <= Section_Count (Item);

   function Section_Of_Item (Item : Session; Key : Long_Integer) return Natural
     with Pre => Screen (Item) = Project;
   --  The place in the outline of the section the item (by its key) is
   --  of; 0 if it is of none.

   function Section_Notes (Item : Session; Which : Positive) return String
     with Pre => Screen (Item) = Project and then Which <= Section_Count (Item);
   --  The notes of the section, as kept.

   function Notes_Shown (Item : Session; Which : Positive) return Boolean
     with Pre => Screen (Item) = Project and then Which <= Section_Count (Item);
   --  Whether the section's notes are shown.

   procedure Toggle_Notes (Item : in out Session; Which : Positive; Focus : Boolean := True)
     with Pre => Screen (Item) = Project and then Which <= Section_Count (Item),
          Post => Notes_Shown (Item, Which) /= Notes_Shown (Item, Which)'Old;
   --  As the section's Notes button does: show its notes, or hide them;
   --  shown, they have the focus if Focus.

   function Documents_In (Item : Session; Which : Positive) return Natural
     with Pre => Screen (Item) = Project and then Which <= Section_Count (Item);
   --  How many items are of the section.

   function Index_Of_Key (Item : Session; Key : Projects.Sections.Section_Id) return Natural
     with Pre => Screen (Item) = Project;
   --  The place in the outline of the section with the key; 0 if there is
   --  none.

   function Section_At (Item : Session; Which : Positive) return Projects.Sections.Section
     with Pre => Screen (Item) = Project and then Which <= Section_Count (Item);
   --  The section, as kept: with its colour, and the item that is its own.

   procedure Reload (Item : in out Session)
     with Pre => Screen (Item) = Project;
   --  The sections have been changed in the database (their links): read
   --  them again, and show them.

   procedure Enter (Item : in out Session)
     with Pre => Screen (Item) = Project;
   --  Show the title, the description and the sections of the project: once
   --  it is current.

   procedure Listen_Block (Item : in out Session; Index : Positive);
   --  Give the widgets of the section's block the procedures they call.

   procedure Leave (Item : in out Session);
   --  Keep what was typed, and let go of the project's sections.

   procedure Shown (Item : in out Session)
     with Pre => Screen (Item) = Project;
   --  The view is to be shown: bring the form up to date with the project,
   --  whose title may have been changed on the toolbar.

   procedure Sync (Item : in out Session)
     with Pre => Screen (Item) = Project;
   --  Keep the title, description and sections' titles if they have been
   --  typed in since.

   procedure Listen (Item : in out Session);
   --  Have the view's buttons and blocks do what they are for.

   procedure Pressed (Item : in out Session; X, Y : Float);
   --  A press of the mouse button at X, Y points: put the colour popout
   --  away if it is not on it.

   procedure Update (Item : in out Session);
   --  For the loop, now and then, whatever view of the project is shown.

   procedure Add_Section (Item : in out Session)
     with Pre => Screen (Item) = Project;
   --  Put a section last, as the Add Section button does, and begin
   --  naming it; nothing is done when there are as many as there can be.

   procedure Move_Section (Item : in out Session; From, To : Positive)
     with Pre  => Screen (Item) = Project
                  and then From <= Section_Count (Item)
                  and then To <= Section_Count (Item),
          Post => Section_Count (Item) = Section_Count (Item)'Old;
   --  Put the From-th section at the To-th, and keep the order.

   procedure Remove_Section (Item : in out Session; Which : Positive)
     with Pre  => Screen (Item) = Project and then Which <= Section_Count (Item),
          Post => Section_Count (Item) = Section_Count (Item)'Old - 1;
   --  Take the section out of the outline.

end Viewer.Outlines;
