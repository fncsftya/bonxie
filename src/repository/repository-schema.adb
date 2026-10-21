with Repository.Directory;
with Repository.Item;
with Repository.Link;
with Repository.Mark;
with Repository.Rule;
with Repository.Section;
with Repository.Word;

package body Repository.Schema is

   procedure Prepare (Store : in out Projects.Store) is
   begin
      --  Those that refer to another come after it.
      Repository.Item.Prepare (Store);
      Repository.Directory.Prepare (Store);
      Repository.Word.Prepare (Store);
      Repository.Mark.Prepare (Store);
      Repository.Link.Prepare (Store);
      Repository.Section.Prepare (Store);
      Repository.Rule.Prepare (Store);
   end Prepare;

end Repository.Schema;
