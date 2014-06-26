# Quire

Creates a smaller sample ePub from a larger ePub file.

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

Validate the sample (uses epubcheck, other criteria):

```ruby
sample.valid?
# => false
sample.errors
# => [ array of epubcheck errors, other errors ]
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

* validate created sample with epubcheck. NOTE: the epub probably won't ever pass.

# TO-DONE

* Include first pages of book: Cover, plate, dedication, full ToC page.
* Include 10% of actual content, that number excludes the cover, plate, toc, etc. Parse the spine somehow to figure out where actual content starts?
* new() options can override the size of the sample.
* Sample content recontexutalize using changes outlined in comments here: https://trello.com/c/BRJkm89j/

