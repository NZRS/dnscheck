-- $Id$

-- DNSCheck Primary Data

CREATE TABLE `messages` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `tag` varchar(255) NOT NULL default '',
  `arguments` tinyint(3) unsigned NOT NULL default 0,
  `language` varchar(16) NOT NULL default 'en-US',
  `formatstring` varchar(255) default NULL,
  `description` text default NULL,
  PRIMARY KEY  (`id`),
  UNIQUE KEY `tag` (`tag`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

CREATE TABLE `queue` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `domain` varchar(255) default NULL,
  `priority` tinyint(3) unsigned NOT NULL default '0',
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=ascii;

CREATE TABLE `results` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `line` int(10) unsigned NOT NULL,
  `timestamp` datetime default NULL,
  `message` varchar(255) NOT NULL default '',
  `arg0` varchar(255) default NULL,
  `arg1` varchar(255) default NULL,
  `arg2` varchar(255) default NULL,
  `arg3` varchar(255) default NULL,
  `arg4` varchar(255) default NULL,
  `arg5` varchar(255) default NULL,
  `arg6` varchar(255) default NULL,
  `arg7` varchar(255) default NULL,
  `arg8` varchar(255) default NULL,
  `arg9` varchar(255) default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=ascii;

CREATE TABLE `tests` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `domain` varchar(255) NOT NULL default '',
  `begin` datetime default NULL,
  `end` datetime default NULL,
  `errors` int(10) unsigned default '0',
  `warnings` int(10) unsigned default '0',
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=ascii;


-- Name Service Providers

CREATE TABLE `nameservers` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `nsp_id` int(10) unsigned NOT NULL,
  `nameserver` varchar(255) NOT NULL default '',
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=ascii;

CREATE TABLE `nsp` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `name` varchar(255) default '',
  `email` varchar(255) default '',
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;


-- Domains and History

CREATE TABLE `domains` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `domain` varchar(255) NOT NULL default '',
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=ascii;

CREATE TABLE `delegation_history` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `domain` varchar(255) NOT NULL default '',
  `nameserver` varchar(255) NOT NULL default '',
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=ascii;
