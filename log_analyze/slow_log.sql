-- MySQL dump 10.11
--
-- Host: localhost    Database: slow_log
-- ------------------------------------------------------
-- Server version	5.0.77-log

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `MASTER_CHANNEL`
--

DROP TABLE IF EXISTS `MASTER_CHANNEL`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `MASTER_CHANNEL` (
  `channel_id` int(11) unsigned NOT NULL,
  `channel_name` varchar(20) NOT NULL,
  `std_name` varchar(20) NOT NULL,
  PRIMARY KEY  (`channel_id`),
  UNIQUE KEY `chanel_name` (`std_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `MASTER_CHANNEL`
--


--
-- Table structure for table `log_data`
--

DROP TABLE IF EXISTS `log_data`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `log_data` (
  `log_id` int(11) unsigned NOT NULL auto_increment,
  `datetime` datetime NOT NULL,
  `method` varchar(20) NOT NULL,
  `resource` text NOT NULL,
  `parametor` text,
  `response_code` smallint(5) unsigned NOT NULL,
  `response_size` int(11) unsigned NOT NULL,
  `response_time` int(11) unsigned NOT NULL,
  `channel_id` int(11) unsigned NOT NULL,
  PRIMARY KEY  (`log_id`),
  UNIQUE KEY `log_id` (`log_id`),
  KEY `channel_id` (`channel_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `log_data`
--

LOCK TABLES `log_data` WRITE;
/*!40000 ALTER TABLE `log_data` DISABLE KEYS */;
/*!40000 ALTER TABLE `log_data` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `log_table_history`
--

DROP TABLE IF EXISTS `log_table_history`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `log_table_history` (
  `table_name` varchar(128) NOT NULL,
  `history_date` datetime NOT NULL,
  `channel_id` int(11) unsigned NOT NULL,
  PRIMARY KEY  (`table_name`),
  UNIQUE KEY `table_name` (`table_name`),
  KEY `channel_id` (`channel_id`),
  CONSTRAINT `channel_id` FOREIGN KEY (`channel_id`) REFERENCES `MASTER_CHANNEL` (`channel_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `log_table_history`
--

LOCK TABLES `log_table_history` WRITE;
/*!40000 ALTER TABLE `log_table_history` DISABLE KEYS */;
/*!40000 ALTER TABLE `log_table_history` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2011-04-13 11:27:46
