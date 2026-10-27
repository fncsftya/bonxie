--  Where bonxie's database is read and written: all of its SQL is in the
--  children, one to a table (or to a few that go together), and nowhere
--  else. What is above them deals in the application's types (see
--  Projects and Items) and never sees a statement.
--
--  Repository.Schema (the tables, made and brought up to date),
--  Repository.Project, Repository.Item, Repository.Directory,
--  Repository.Word, Repository.Mark and Repository.Link.

package Repository is
end Repository;
