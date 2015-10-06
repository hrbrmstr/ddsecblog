#' @import knitr
#' @import rmarkdown
#' @import yaml
#' @export
post <- function() {

  output_format(knitr = knitr_options(opts_chunk=list(dev="png", fig.retina=2)),
                pandoc = pandoc_options(to="markdown_github"),
                clean_supporting = FALSE,
                post_processor=post_processor)

}


post_processor <- function(metadata, input_file, output_file, clean, verbose) {
  input_lines <- readLines(input_file, warn = FALSE)

  partitioned <- partition_yaml_front_matter(input_lines)
  if (!is.null(partitioned$front_matter)) {
    output_lines <- c(partitioned$front_matter,
                      "",
                      readLines(output_file, warn = FALSE))
    writeLines(output_lines, output_file, useBytes = TRUE)
  }
  output_file
}

validate_front_matter <- function(front_matter) {
  front_matter <- trim_trailing_ws(front_matter)
  if (grepl(":$", front_matter))
    stop("Invalid YAML front matter (ends with ':')", call. = FALSE)
}

parse_yaml_front_matter <- function(input_lines) {

  partitions <- partition_yaml_front_matter(input_lines)
  if (!is.null(partitions$front_matter)) {
    front_matter <- partitions$front_matter
    if (length(front_matter) > 2) {
      front_matter <- front_matter[2:(length(front_matter)-1)]
      front_matter <- paste(front_matter, collapse="\n")
      validate_front_matter(front_matter)
      parsed_yaml <- yaml_load_utf8(front_matter)
      if (is.list(parsed_yaml))
        parsed_yaml
      else
        list()
    }
    else
      list()
  }
  else
    list()
}

partition_yaml_front_matter <- function(input_lines) {

  validate_front_matter <- function(delimiters) {
    if (length(delimiters) >= 2 &&
        (delimiters[2] - delimiters[1] > 1) &&
        grepl("^---\\s*$", input_lines[delimiters[1]])) {
      # verify that it's truly front matter (not preceded by other content)
      if (delimiters[1] == 1)
        TRUE
      else
        is_blank(input_lines[1:delimiters[1]-1])
    } else {
      FALSE
    }
  }

  # is there yaml front matter?
  delimiters <- grep("^(---|\\.\\.\\.)\\s*$", input_lines)
  if (validate_front_matter(delimiters)) {

    front_matter <- input_lines[(delimiters[1]):(delimiters[2])]

    fm <- yaml.load(paste0(front_matter[2:(length(front_matter)-1)], collapse="\n"))
    fm_strs <- sapply(c("Title", "Date", "Slug", "Tags", "Category", "Author"), function(x) {
        sprintf("%s: %s", x, fm[[x]])
    })
    fm_strs <- unlist(c(fm_strs,
                 sprintf("Slug: %s", tolower(gsub("\\-+", "\\-", gsub("[^[:alnum:]]", "-", fm[["Title"]])))),
                 "Status: draft"))


    input_body <- c()

    if (delimiters[1] > 1)
      input_body <- c(input_body,
                      input_lines[1:delimiters[1]-1])

    if (delimiters[2] < length(input_lines))
      input_body <- c(input_body,
                      input_lines[-(1:delimiters[2])])

    list(front_matter = fm_strs,
         body = input_body)
  }
  else {
    list(front_matter = NULL,
         body = input_lines)
  }
}

is_blank <- function(x) {
    if (length(x))
        all(grepl("^\\s*$", x))
    else TRUE
}

trim_trailing_ws <- function (x) {
  sub("\\s+$", "", x)
}

yaml_load_utf8 <- function(string, ...) {
  string <- paste(string, collapse = '\n')
  mark_utf8(yaml::yaml.load(enc2utf8(string), ...))
}

yaml_load_file_utf8 <- function(input, ...) {
  yaml_load_utf8(readLines(input, encoding = 'UTF-8'), ...)
}

mark_utf8 <- function(x) {
  if (is.character(x)) {
    Encoding(x) <- 'UTF-8'
    return(x)
  }
  if (!is.list(x)) return(x)
  attrs <- attributes(x)
  res <- lapply(x, mark_utf8)
  attributes(res) <- attrs
  res
}
