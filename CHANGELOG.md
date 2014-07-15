## Change Log

### 0.0.3 July 15 2014

Book ID 4331:
  * content src in navPoint included a hash-path (foo.html#bar), and
    Sample#content_sample_size_in_bytes was choking. Made that method be able
    handle those kind of src references.

### 0.0.2 July 2 2014

Book ID 2973:
  * Book where NCX TOC didn't have ID of 'toc'. Removed the ID constraint
    from Quire::Opf#find_toc_item.

Book ID 4198:
 * Content was living in nested directories. Gem handles these now.
 * Image links using paths with '../'. Matcher understands now.
 * strip! on miletype was removing whole file. Change to explicit gsub removal
   of CRs and CRLFs.

General: Better reporting of errors when source file can't be loaded.

### 0.0.1 June 30 2014

Initial Release

