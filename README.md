# Quire

Creates a smaller sample ePub from a larger ePub file.

Sample size configurable, default is 10% of the text content of unique documents
referenced in the table-of-contents.

If the sample size limit occurs in the middle of a document, that document will
be truncated and any open HTML tags will be closed.

Files that are not referenced in the sample content not be included in the
output ePub. This includes images, stylesheet, and other document that are not
referenced in the table-of-contents.

Link targets within the table-of-contents to documents that have been removed
will be replaced with empty strings. This will usually be reported as an error
within ePubCheck but most ePub readers will accept it.

The name? http://en.wikipedia.org/wiki/Paper_quire#Quire

## Usage

Load the source epub:

```ruby
sample = Quire.new(path_to_source_epub)

sample = Quire.new(http_url_of_source_epub)

sample = Quire.new(source_epub_as_io_object)

sample = Quire.new(path, {
  sample_size: 5                      # sample size as percent of original,
  destination: '/somewhere/else.epub' # output path of newly generated sample
})
```

Output the generated sample epub as string:

```ruby
sample_epub_data = sample.to_s(destination_path)
```

Output the generated sample epub as IO object:

```ruby
sample_epub_data = sample.io(destination_path)
```

Write the generated epub sample to disk:

```ruby
sample.write(destination_path)
sample.save(destination_path) # synonym for #write

sample.write # if destination path was passed in constructor options
```

## TODO

* validate created sample with epubcheck. NOTE: the epub probably won't ever pass completely because of the way the links are rewritten.

# TO-DONE

* Include first pages of book: Cover, plate, dedication, full ToC page.
* Include 10% of actual content, that number excludes the cover, plate, toc, etc. Parse the spine somehow to figure out where actual content starts?
* new() options can override the size of the sample.
* Sample content recontexutalize using changes outlined in comments here: https://trello.com/c/BRJkm89j/
