package main

import (
	"encoding/json"
	"fmt"
	"log"
	"time"

	"github.com/aws/aws-sdk-go/aws/awserr"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/dynamodb"
)

type Record struct {
	Key       string
	RemoteID  string
	OtherData map[string]int
	Timestamp int64
}

type NginxLog struct {
	ID            string
	Time          string
	BodyBytesSent string
	BytesSent     string
	ForWardedFor  string
	QueryString   string
	Referer       string
	RemoteAddr    string
	RequestLength string
	RequestMethod string
	RequestTime   string
	RequestURI    string
	Status        string
	Tag           string
	Useragent     string
}

func main() {
	//testTableDelete()
	//chack table status

	//testTableCreate()
	//chack table status
	//if creating,wait for active
	sess, err := session.NewSession(&aws.Config{
		Region: aws.String("ap-northeast-1")},
	)

	if err != nil {
		fmt.Println(err.Error())
	}

	// Create DynamoDB client
	svc := dynamodb.New(sess)
	/*
		result, err := testTablePutItem(svc, "test")
		fmt.Println("PutItemResult ---------------", result)
		fmt.Println("---------------")

		testTableQuery(svc, "test")

		rollbackTest(svc, "test")

		dupTest(svc, "test")
	*/
	testScanTable(svc, "php_test")

}

func testTablePutItem(svc *dynamodb.DynamoDB, tableName string) (result *dynamodb.PutItemOutput, err error) {
	fmt.Println("execute PutItem")

	Item := map[string]*dynamodb.AttributeValue{
		"key": {
			S: aws.String("golang_test"),
		},
		"Artist": {
			S: aws.String("No One You Know"),
		},
		"SongTitle": {
			S: aws.String("Call Me Today"),
		},
	}

	input := &dynamodb.PutItemInput{
		Item: Item,
		ReturnConsumedCapacity: aws.String("TOTAL"),
		TableName:              aws.String("test"),
	}

	result, err = svc.PutItem(input)

	if err != nil {
		// Print the error, cast err to awserr.Error to get the Code and
		// Message from an error.
		fmt.Println(err.Error())
		return
	}

	return result, err
}

func testTableQuery(svc *dynamodb.DynamoDB, tableName string) {
	fmt.Println("execute query")

	input := &dynamodb.QueryInput{
		ExpressionAttributeValues: map[string]*dynamodb.AttributeValue{
			":v1": {
				S: aws.String("B-2029"),
			},
		},
		ExpressionAttributeNames: map[string]*string{
			"#K": aws.String("PK"),
			"#S": aws.String("SK"),
			"#B": aws.String("BillAmount"),
		},
		KeyConditionExpression: aws.String("#K = :v1"),
		TableName:              aws.String("InvoiceandBilling"),
		ProjectionExpression:   aws.String("#K,#S,#B"),
	}

	result, err := svc.Query(input)

	if err != nil {
		println(err.Error())
	}
	fmt.Println(result)

}

//https://blog.mmmcorp.co.jp/blog/2018/11/29/dynamo-transaction/

func rollbackTest(svc *dynamodb.DynamoDB, tableName string) {
	fmt.Println("execute rollback test")

	_, err := svc.TransactWriteItems(&dynamodb.TransactWriteItemsInput{
		TransactItems: []*dynamodb.TransactWriteItem{
			// 更新できる
			{
				Put: &dynamodb.Put{
					TableName: aws.String(tableName),
					Item: map[string]*dynamodb.AttributeValue{
						"key": {
							S: aws.String("Item-1"),
						},
					},
				},
			},
			// 更新エラーとなる
			{
				Put: &dynamodb.Put{
					TableName: aws.String(tableName),
					Item: map[string]*dynamodb.AttributeValue{
						"key": {
							S: aws.String("Item-2"),
						},
					},
					ConditionExpression: aws.String("ForceError = :true"), // この条件で更新処理を失敗させる
					ExpressionAttributeValues: map[string]*dynamodb.AttributeValue{
						":true": {BOOL: aws.Bool(true)},
					},
				},
			},
		},
	})
	if err != nil {
		if awsErr, ok := err.(awserr.Error); ok {
			log.Println("Error:", awsErr.Code(), awsErr.Message())
		}
	}
}

func dupTest(svc *dynamodb.DynamoDB, tableName string) {
	fmt.Println("execute duptest")

	dupID := "Item-1"

	result, err := svc.TransactWriteItems(&dynamodb.TransactWriteItemsInput{
		TransactItems: []*dynamodb.TransactWriteItem{
			{
				Put: &dynamodb.Put{
					TableName: aws.String(tableName),
					Item: map[string]*dynamodb.AttributeValue{
						"key": {
							S: aws.String(dupID),
						},
					},
				},
			},
			{
				Put: &dynamodb.Put{
					TableName: aws.String(tableName),
					Item: map[string]*dynamodb.AttributeValue{
						"key": {
							S: aws.String(dupID),
						},
					},
				},
			},
		},
	})
	if err != nil {
		if awsErr, ok := err.(awserr.Error); ok {
			log.Println("Error:", awsErr.Code(), awsErr.Message())
		}
	}
	fmt.Println(result)
}

func testScanTable(svc *dynamodb.DynamoDB, tableName string) {
	fmt.Println("execute ScanTable")

	/*
		scanParams := &dynamodb.ScanInput{
			TableName:aws.String("access_log_range"),
			AttributesToGet:[]*string{
				aws.String("id"),
				aws.String("time"),
				aws.String("body_bytes_sent"),
				aws.String("bytes_sent"),
				aws.String("forwardedfor"),
				aws.String("query_string"),
				aws.String("referer"),
				aws.String("remote_addr"),
				aws.String("request_length"),
				aws.String("request_method"),
				aws.String("request_time"),
				aws.String("request_uri"),
				aws.String("status"),
				aws.String("tag"),
				aws.String("useragent"),
			},
			//Limit: aws.Int64(1000000),
		}
	*/

	scanParams := &dynamodb.ScanInput{
		AttributesToGet:           nil,
		ConditionalOperator:       nil,
		ConsistentRead:            nil,
		ExclusiveStartKey:         nil,
		ExpressionAttributeNames:  nil,
		ExpressionAttributeValues: nil,
		FilterExpression:          nil,
		IndexName:                 nil,
		Limit:                     aws.Int64(10000),
		ProjectionExpression:      nil,
		ReturnConsumedCapacity:    aws.String("TOTAL"),
		ScanFilter:                nil,
		Segment:                   nil,
		Select:                    nil,
		TableName:                 aws.String("result"),
		TotalSegments:             nil,
	}

	resp, err := svc.Scan(scanParams)
	if err != nil {
		fmt.Println(err.Error())
		return
	}

	//fmt.Println("scanObject ", resp)

	log.Println(resp.LastEvaluatedKey)
	pageNum := 0
	err = svc.ScanPages(scanParams,
		func(page *dynamodb.ScanOutput, lastPage bool) bool {
			pageNum++
			log.Println("Now scan page is ", page.ConsumedCapacity)
			_, e := json.Marshal(page.Items)
			if e != nil {
				fmt.Println(e)
			} else {
				//fmt.Println(pageResult)
			}
			return true
		})

	if err != nil {
		fmt.Println(err.Error())
		return
	}

	log.Println("-------scan end--------")
	log.Println("last page num is ", pageNum)
	log.Println("start time:", time.Now())
	log.Println("end time:", time.Now())
}

func testTableCreate() (*dynamodb.CreateTableOutput, error) {
	fmt.Println("execute test Table Create")

	sess, err := session.NewSession(&aws.Config{
		Region: aws.String("ap-northeast-1")},
	)

	// Create DynamoDB client
	svc := dynamodb.New(sess)

	params := &dynamodb.CreateTableInput{
		AttributeDefinitions: []*dynamodb.AttributeDefinition{ // Required
			{ // Required
				AttributeName: aws.String("Key"), // Required
				AttributeType: aws.String("S"),   // Required
			},
		},
		KeySchema: []*dynamodb.KeySchemaElement{ // Required
			{ // Required
				AttributeName: aws.String("Key"),  // Required
				KeyType:       aws.String("HASH"), // Required
			},
		},
		ProvisionedThroughput: &dynamodb.ProvisionedThroughput{ // Required
			ReadCapacityUnits:  aws.Int64(100), // Required
			WriteCapacityUnits: aws.Int64(100), // Required
		},
		TableName: aws.String("result"), // Required
		StreamSpecification: &dynamodb.StreamSpecification{
			StreamEnabled:  aws.Bool(true),
			StreamViewType: aws.String("NEW_AND_OLD_IMAGES"),
		},
	}

	resp, err := svc.CreateTable(params)

	if err != nil {
		log.Println(err.Error())
	}

	fmt.Println(resp)
	return resp, err
}

func testTableDelete() {
	fmt.Println("test Table Delete")

	sess, err := session.NewSession(&aws.Config{
		Region: aws.String("ap-northeast-1")},
	)

	// Create DynamoDB client
	svc := dynamodb.New(sess)

	params := &dynamodb.DeleteTableInput{
		TableName: aws.String("result"), // Required
	}
	resp, err := svc.DeleteTable(params)

	if err != nil {
		log.Println(err.Error())
		return
	}

	fmt.Println(resp.TableDescription.TableStatus)
}
