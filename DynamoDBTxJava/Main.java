import com.amazonaws.services.dynamodbv2.AmazonDynamoDB;
import com.amazonaws.services.dynamodbv2.AmazonDynamoDBClientBuilder;
import com.amazonaws.services.dynamodbv2.document.DynamoDB;
import com.amazonaws.services.dynamodbv2.document.Item;
import com.amazonaws.services.dynamodbv2.document.Table;
import com.amazonaws.services.dynamodbv2.model.*;

import java.util.Arrays;
import java.util.Collection;
import java.util.HashMap;


public class Main {

    public static void main(String[] args) {
        System.out.println("Hello World!");

        AmazonDynamoDB client = AmazonDynamoDBClientBuilder.standard().build();
        DynamoDB dynamoDB = new DynamoDB(client);

        Item item = new Item()
                .withPrimaryKey("key","java-test")
                .withString("java","doukana");

        Table putTable = dynamoDB.getTable("test");
        putTable.putItem(item);

        HashMap<String, AttributeValue> orderItem = new HashMap<>();
        orderItem.put("key", new AttributeValue("100"));
        orderItem.put("key", new AttributeValue("101"));

        Put createOrder = new Put()
                .withTableName("test")
                .withItem(orderItem)
                .withReturnValuesOnConditionCheckFailure(ReturnValuesOnConditionCheckFailure.ALL_OLD)
                .withConditionExpression("attribute_not_exists(test)");

        Collection<TransactWriteItem> actions = Arrays.asList(
                new TransactWriteItem().withPut(createOrder));

        TransactWriteItemsRequest placeOrderTransaction = new TransactWriteItemsRequest()
                .withTransactItems(actions)
                .withReturnConsumedCapacity(ReturnConsumedCapacity.TOTAL);

        try {
            TransactWriteItemsResult resut = client.transactWriteItems(placeOrderTransaction);
            System.out.println("Transaction Successful");

        } catch (ResourceNotFoundException rnf) {
            System.err.println("One of the table involved in the transaction is not found" + rnf.getMessage());
        } catch (InternalServerErrorException ise) {
            System.err.println("Internal Server Error" + ise.getMessage());
        } catch (TransactionCanceledException tce) {
            System.out.println("Transaction Canceled " + tce.getCancellationReasons());
        }

    }
}

