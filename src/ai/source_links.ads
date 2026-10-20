--  Which addresses are of PDFs, and which pages are the page of one. A PDF
--  is shown well in a project (drawn from its own shapes and text, not
--  photographed), so when a search finds a page that is only the front of a
--  paper (arXiv's abstract, a journal's preview) its PDF is wanted, and so is a
--  PDF that a site gives at an address with no .pdf at its end (the browser
--  shows those in a viewer, as a picture of a page, which is poor).
package Source_Links is

   function Is_Document (URL : String) return Boolean;
   --  Whether the address is of a PDF: it ends in .pdf (the query and the
   --  fragment are no part of the ending), or a segment of its path is "pdf" or
   --  "epdf" and the address goes on from it (arXiv's /pdf/2501.17078, T&F's
   --  /doi/pdf/10.1080/...). It may turn out not to be one when it is fetched:
   --  see Is_PDF_File.

   function Direct_Document (URL : String) return String
     with Post => Direct_Document'Result'Length = 0 or else Is_Document (Direct_Document'Result);
   --  The address of the PDF that a page at a known site is the front of: for
   --  arXiv, /abs/, /html/ and /pdf/ of a paper are all /pdf/<id>.pdf; for
   --  Taylor & Francis, a /doi/ abs, full, epdf or figure page is /doi/pdf/ of the
   --  same DOI; for the ACM Digital Library, a /doi/ page of a paper (with abs, full,
   --  fullHtml, epdf or none before its DOI) is /doi/pdf/ of it. Empty if the address
   --  is none of those (or is no address).

   function Is_PDF_File (Start : String) return Boolean;
   --  Whether a file that begins with Start (its first few bytes) is a PDF.

   function Name_Of (URL : String) return String
     with Post => Name_Of'Result'Length <= URL'Length;
   --  What the address names, to call a source by when nothing better is known:
   --  the last part of its path, less its ending (a number, or one with a version, after the last dot is
   --  no ending, as in a DOI or an arXiv id), the query and the fragment; or, if the path has a
   --  DOI in it (a segment that starts 10. and what is after), the DOI.

end Source_Links;
