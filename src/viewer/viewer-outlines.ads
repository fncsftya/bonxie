--  The outline view: a form of the project's title and description at the
--  left, and at the right the titles of its sections, as blocks that are
--  dragged, or moved up and down, into the order they are to come in, and
--  removed. Everything is kept as it is typed or done.
private package Viewer.Outlines is

   function Section_Count (Item : Session) return Natural
     with Pre => Screen (Item) = Project;

   function Section_Title (Item : Session; Which : Positive) return String
     with Pre => Screen (Item) = Project and then Which <= Section_Count (Item);

   procedure Enter (Item : in out Session)
     with Pre => Screen (Item) = Project;
   --  Show the title, the description and the sections of the project: once
   --  it is current.

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
