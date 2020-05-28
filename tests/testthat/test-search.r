context("search")

invisible(connect())

test_that("basic search works", {

  a <- Search(index="shakespeare")
  expect_equal(names(a), c('took','timed_out','_shards','hits'))
  expect_is(a, "list")
  expect_is(a$hits$hits, "list")
  expect_equal(names(a$hits$hits[[1]]), c('_index','_type','_id','_score','_source'))
})

test_that("search for document type works", {
  b <- Search(index="shakespeare", type="line")
  expect_match(vapply(b$hits$hits, "[[", "", "_type"), "line")
})

test_that("search for specific fields works", {

  if (gsub("\\.", "", ping()$version$number) >= 500) {
    c <- Search(index="shakespeare", body = '{
      "_source": ["play_name", "speaker"]
    }')
    expect_equal(sort(unique(lapply(c$hits$hits, function(x) names(x$`_source`)))[[1]]), c('play_name','speaker'))
  } else {
    c <- Search(index="shakespeare", fields=c('play_name','speaker'))
    expect_equal(sort(unique(lapply(c$hits$hits, function(x) names(x$fields)))[[1]]), c('play_name','speaker'))
  }
})

test_that("search paging works", {

  if (gsub("\\.", "", ping()$version$number) >= 500) {
    d <- Search(index = "shakespeare", size = 1, body = '{
      "_source": ["text_entry"]
    }')$hits$hits
  } else {
    d <- Search(index="shakespeare", size=1, fields='text_entry')$hits$hits
  }
  expect_equal(length(d), 1)
})

test_that("search terminate_after parameter works", {

  e <- Search(index="shakespeare", terminate_after=1)
  expect_is(e, "list")
})

test_that("getting json data back from search works", {

  suppressMessages(require('jsonlite'))
  f <- Search(index="shakespeare", type="scene", raw=TRUE)
  expect_is(f, "character")
  expect_true(jsonlite::validate(f))
  expect_is(jsonlite::fromJSON(f), "list")
})

test_that("Search works with special characters - +", {
  invisible(tryCatch(index_delete("a+b"), error = function(e) e))
  invisible(index_create("a+b"))
  invisible(docs_create(index = "a+b", type = "wiz", id=1, body=list(a="ddd", b="eee")))
  
  Sys.sleep(1)
  aplusb <- Search(index = "a+b")
  
  expect_is(aplusb, "list")
  expect_equal(length(aplusb$hits$hits), 1)
  expect_equal(vapply(aplusb$hits$hits, "[[", "", "_index"), 'a+b')
})

test_that("Search works with special characters - ^", {
  invisible(tryCatch(index_delete("a^z"), error = function(e) e))
  invisible(index_create("a^z"))
  invisible(docs_create(index = "a^z", type = "bang", id=1, body=list(a="fff", b="ggg")))
  
  Sys.sleep(1)
  ahatz <- Search(index = "a^z")
  
  expect_is(ahatz, "list")
  expect_equal(length(ahatz$hits$hits), 1)
  expect_equal(vapply(ahatz$hits$hits, "[[", "", "_index"), 'a^z')
})
  
test_that("Search works with special characters - $", {
  invisible(tryCatch(index_delete("a$z"), error = function(e) e))
  invisible(index_create("a$z"))
  invisible(docs_create(index = "a$z", type = "bang", id=1, body=list(a="fff", b="ggg")))
  
  Sys.sleep(1)
  adollarz <- Search(index = "a$z")
  
  expect_is(adollarz, "list")
  expect_equal(length(adollarz$hits$hits), 1)
  expect_equal(vapply(adollarz$hits$hits, "[[", "", "_index"), 'a$z')
})

test_that("Search works with wild card", {
  if (index_exists("voobardang1")) {
    invisible(index_delete("voobardang1"))
  }
  invisible(index_create("voobardang1"))
  invisible(docs_create(index = "voobardang1", type = "wiz", id=1, body=list(a="ddd", b="eee")))

  if (index_exists("voobardang2")) {
    invisible(index_delete("voobardang2"))
  }
  index_create("voobardang2")
  invisible(docs_create(index = "voobardang2", type = "bang", id=1, body=list(a="fff", b="ggg")))
  
  Sys.sleep(1)
  aster <- Search(index = "voobardang*")
  
  expect_is(aster, "list")
  expect_equal(length(aster$hits$hits), 2)
  expect_equal(vapply(aster$hits$hits, "[[", "", "_index"), c('voobardang1', 'voobardang2'))
  expect_equal(vapply(aster$hits$hits, "[[", "", "_id"), c('1', '1'))
})

test_that("Search fails as expected", {

  aggs <- list(aggs = list(stats = list(stfff = list(field = "text_entry"))))
  if (gsub("\\.", "", ping()$version$number) >= 500) {
    if (gsub("\\.", "", ping()$version$number) >= 530) {
      expect_error(Search(index = "shakespeare", body = aggs), 
                   "Unknown BaseAggregationBuilder \\[stfff\\]")
    } else {
      expect_error(Search(index = "shakespeare", body = aggs), 
                   "Could not find aggregator type \\[stfff\\] in \\[stats\\]")
    }
  } else {
    expect_error(Search(index = "shakespeare", body = aggs), "all shards failed")
  }

  expect_error(Search(index = "shakespeare", type = "act", sort = "text_entryasasfd"), "all shards failed")

  expect_error(Search(index = "shakespeare", size = "adf"), "size should be a numeric or integer class value")

  expect_error(Search(index = "shakespeare", from = "asdf"), "from should be a numeric or integer class value")

  expect_error(Search(index="shakespeare", q="~text_entry:ma~"), "all shards failed")
  
  if (es_version() < 600) {
    expect_error(Search(index="shakespeare", q="line_id:[10 TO x]"), 
                 "all shards failed||SearchPhaseExecutionException")
  }

  expect_error(Search(index="shakespeare", terminate_after="Afd"), 
               "terminate_after should be a numeric")
})
