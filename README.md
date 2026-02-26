perl-api
========

This Perl package is a lightweight wrapper for Interaxiom API's and is the easiest way to use interaxiom.com.au API's in Perl CGI applications.

## Basic example

```perl
#!/usr/bin/env perl

# Visit https://myaccount.interaxiom.com.au/api to get your credentials

use strict;
use warnings;
use Data::Dumper;
use InteraxiomApi;

my $ApiInteraxiom = InteraxiomApi->new(
    timeout => 10,
    type => InteraxiomApi::API_MYACCOUNT,
	applicationKey => $applicationKey,
	publicKey => $publicKey,
	privateKey => $privateKey,
);

my $result = $ApiInteraxiom->get(path => "/v1/");

if (!$result) {
    printf("Failed to retrieve result: %s\n", $result);
    return 0;
} else {
	$result = $result->content();
}

printf("Connected to endpoint: %s\n", $result->{'endpoint'});

```

Quickstart
----------

To start using this wrapper, you must first download it from the git repository.

Quick download with the following command:

```
$ cd /usr/local/src
$ git clone https://github.com/interaxiom/perl-api.git
```

## Installation

```
$ cd perl-api
$ perl Makefile.PL
$ make
$ make test
$ make install
```

Note: You can add the perl-api library to your application without having to compile and install the package if required:

```
use lib "vendor/interaxiom/perl-api/lib";
```

Interaxiom Examples
-------------------

Do you want to use Interaxiom APIs? Maybe the script you want is already written in the [examples](https://github.com/interaxiom/perl-api/tree/master/examples) part of this repository!

Supported APIs
--------------

The following endpoints are available for public use:

## My Account

 * ```type => InteraxiomApi::API_MYACCOUNT;```
 * Documentation: https://myaccount.interaxiom.com.au/knowledgebase/api
 * Customer Support: development@interaxiom.com.au
 * Console: https://myaccount.interaxiom.com.au/api
 * Create application credentials: https://myaccount.interaxiom.com.au/api

## Related links

 * Contribute: https://github.com/interaxiom/perl-api
 * Report bugs: https://github.com/interaxiom/perl-api/issues



