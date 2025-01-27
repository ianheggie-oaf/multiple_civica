This is a scraper that runs on [Morph](https://morph.io). To get started [see the documentation](https://morph.io/documentation)

Add any issues to https://github.com/planningalerts-scrapers/issues/issues

## To run the scraper

```bash
bundle exec ruby scraper.rb
```

## To run the tests

```bash
bundle exec rake
```
OR
```bash
bin/rake
```

## Running under morph.io

Some of the authorities require an Australia proxy, specifically:

  * albury - execution expired error - trying timeout: 45
  * bega_valley - execution expired error - trying timeout: 45
  * bundaberg - ERROR: 403 => Net::HTTPForbidden for https://da.bundaberg.qld.gov.au/ -- unhandled response
  * port_stephens - execution expired - trying timeout: 45

I have created the [down\_under](https://github.com/ianheggie/down_under)
project for my own australian proxy. You are free to use my project, but
you will need to pay for your own linode VPS.

Set `MORPH_AUSTRALIA_PROXY` to the proxy setting reported by `bin/status`

### To force testing using fresh cache of external sites

*Testing is performed using a cached copy of the external sites.*
*Clobber the cache to force testing against recent copies of external site results.*

```bash
bundle exec rake clobber_cache
```
OR
```bash
bin/rake clobber_cache
```

## Report on morph.io dev/test and live status pages

```bash
bin/rake morph_status:report
```

Produces a table report by authority of:

* Week, Month, Population, Warning - from Morph.io Live Status Page
* Test - local spec/expected/AUTHORITY.yml record count
* Morph - records collected by test of this repo on Morph.io

And then a Summary by Status detailing recommended Actions to Take

You will need to set an environment variable (eg via .envrc file and direnv command):
* MORPH_API_KEY - so the report can query the database updated on morph.io by your local repository

## To run style and coding checks

```bash
bundle exec rubocop
```

## Available filters

Optionally set the following ENV variables before running scraper.rb or tests:

* `LIMIT=5` - to limit the number of records to 5 (for example) for quick test (different cache files used)
* `AUTHORITIES=name,name` - to run/test with a subset of authorities
* `DEBUG=1` - to show the GET and POST calls to the external site
* `FAIL_FAST=1` - to make spec stop on first failure
* `UNKNOWN_IS_NOT_FATAL=1` - for when you get sick of adding all the new determinations one test run at a time

## What a Masterview website looks like

![Sign up](https://github.com/planningalerts-scrapers/multiple_masterview/raw/master/screenshots/all.jpg)

(To update this screenshot run `bundle exec rake screenshots`)
