#!/usr/bin/perl
#
# $Id$
#
# Copyright (c) 2007 .SE (The Internet Infrastructure Foundation).
#                    All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
# GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
# IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
# OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN
# IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
######################################################################

package DNSCheck::Engine;

require 5.8.0;
use warnings;
use strict;

use Date::Format;
use DBI;
use DNSCheck;
use Data::Dumper;

######################################################################

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = {};

    my $config = shift;

    unless ($config->{db_driver}) {
        $config->{db_driver} = "mysql";
    }

    unless ($config->{db_host}) {
        $config->{db_dhost} = "localhost";
    }

    unless ($config->{db_port}) {
        $config->{db_port} = 3306;
    }

    unless ($config->{db_database}) {
        $config->{db_database} = "dnscheck";
    }

    unless ($config->{db_username}) {
        $config->{db_username} = "engine";
    }

    unless ($config->{db_password}) {
        $config->{db_password} = "";
    }

    my $source = sprintf(
        "DBI:%s:database=%s;host=%s;port=%d",
        $config->{db_driver}, $config->{db_database},
        $config->{db_host},   $config->{db_port}
    );

    $self->{dbh} =
      DBI->connect($source, $config->{db_username}, $config->{db_password})
      || die "can't connect to database $source";

    $self->{verbose} = $config->{verbose};
    $self->{debug}   = $config->{debug};

    $self->{dnscheck} = new DNSCheck($config);

    bless $self, $class;
}

sub DESTROY {
    my $self = shift;

    $self->{dbh}->disconnect();
}

sub process {
    my $self  = shift;
    my $count = shift;

    my $dbh = $self->{dbh};

    my $batch = _dequeue($dbh, $count);

    printf("Got %d entries from queue\n", scalar(@$batch))
      if ($self->{verbose});

    foreach my $q (@$batch) {
        printf("Testing %s (id=%d)\n", $q->{domain}, $q->{id})
          if ($self->{verbose});

        $self->test($q->{domain});

        printf("Deleting %s (id=%d) from queue\n", $q->{domain}, $q->{id})
          if ($self->{verbose});

        $dbh->do(sprintf("DELETE FROM queue WHERE id=%d ", $q->{id}));
    }
}

sub _dequeue {
    my $dbh   = shift;
    my $count = shift;

    my $limit = "";

    $limit = sprintf(" LIMIT %d", $count) if ($count);

    # FIXME: check integrity of dequeueing

    $dbh->begin_work;

    my $batch = $dbh->selectall_arrayref(
        " SELECT id, domain FROM queue "
          . " WHERE inprogress IS NULL "
          . " ORDER BY priority "
          . $limit,
        { Slice => {} }
    );

    foreach my $q (@$batch) {
        $dbh->do(
            sprintf(
                " UPDATE queue SET inprogress = NOW() WHERE id =
              %d ", $q->{id}
            )
        );
    }

    $dbh->commit;

    return $batch;
}

sub test {
    my $self = shift;
    my $zone = shift;

    my $logger = $self->{dnscheck}->logger;
    my $dbh    = $self->{dbh};

    $logger->clear($zone);
    $logger->logname($zone);

    my $timeformat = "%Y-%m-%d %H:%m:%S";

    my $count_error   = 0;
    my $count_warning = 0;
    my $count_notice  = 0;
    my $count_info    = 0;

    $dbh->do(
        sprintf("INSERT INTO tests(domain,begin) VALUES(%s,NOW())",
            $dbh->quote($zone))
    );

    my $id = $dbh->{'mysql_insertid'};

    my $history = $dbh->selectcol_arrayref(
        sprintf(
            "SELECT DISTINCT nameserver FROM delegation_history "
              . "WHERE domain=%s",
            $dbh->quote($zone)
        )
    );

    DNSCheck::zone($self->{dnscheck}, $zone, $history);

    $dbh->do(sprintf("UPDATE tests SET end=NOW() WHERE id=%d", $id));

    my $line = 0;

    foreach my $logentry (@{ $logger->export }) {
        my $timestamp = shift @$logentry;
        my $context   = shift @$logentry;
        my $level     = shift @$logentry;
        my $tag       = shift @$logentry;
        my @arg       = @$logentry;

        $line++;

        $count_error++   if ($level eq "ERROR");
        $count_warning++ if ($level eq "WARNING");
        $count_notice++  if ($level eq "NOTICE");
        $count_info++    if ($level eq "INFO");

        $dbh->do(
            sprintf(
                "INSERT INTO results "
                  . "(test_id,line,timestamp,level,message,"
                  . "arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9) "
                  . "VALUES(%d,%d,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)",
                $id,
                $line,
                $dbh->quote(time2str($timeformat, $timestamp)),
                $dbh->quote($level),
                $dbh->quote($tag),
                $dbh->quote($arg[0]),
                $dbh->quote($arg[1]),
                $dbh->quote($arg[2]),
                $dbh->quote($arg[3]),
                $dbh->quote($arg[4]),
                $dbh->quote($arg[5]),
                $dbh->quote($arg[6]),
                $dbh->quote($arg[7]),
                $dbh->quote($arg[8]),
                $dbh->quote($arg[9])
            )
        );
    }

    $dbh->do(
        sprintf(
            "UPDATE tests SET "
              . "count_error=%d,count_warning=%d,"
              . "count_notice=%d,count_info=%d "
              . "WHERE id=%d",
            $count_error, $count_warning, $count_notice, $count_info, $id
        )
    );

    $logger->clear($zone);
}

1;

__END__
