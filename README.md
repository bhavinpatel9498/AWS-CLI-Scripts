# Steps to Run mp3

### 1. Copy create-mp3.sh, create-env-mp3.sh, destroy-mp3.sh and create-env-mp3-standalone.sh to your vagrant box in same directory.
### 2. Run destroy scripts to make sure everything is clean. You should expect o/p something like below screenshot if everything is clean. If there is something it would be removed and status of the operation will be displayed on console.

| <img src="https://github.com/illinoistech-itm/bpatel68/blob/master/itmo-544/mp3/images/pic1.jpg" alt="" style="width: 400px;"/> |
|:--:| 
| *Sample o/p of initial destroy scripts* |

### 3. Run create-mp3.sh to create EC2 instances, ELB, EBS, S3 bucket, ElastiCache (Redis), SQS, Launch configurations, Auto Scaling Group, and RDS (Read replica too). Sample script with positional parameters provided below. All other parameters are same as mp1 except the last one where you have to give IAM role name.

   *./create-mp3.sh ami-0f3871024fa157995 bhavin_itmo544_key itmo544-default-group-bhavin 1 bhavin-elb-itmo544 bpatel68-data-mp2 admin-role*

   Note:
   * Always use my custom AMI image ami-0f3871024fa157995
   * Always pass S3 bucket name as bpatel68-data-mp2.
   * SQS Name is used as bpatel68-sqs-mp2-msg. There is no positional param for this.
   * ElastiCache is used as bpatel68-mp3-cache. There is no positional param for this.
   * Replace your key and group name.
   * Necessary ports are open for your security group. I am opening ports 3000, 6379 and 3306 via commands but this is just to make sure they are open.
   * Make sure your AWS CLI user has AdministratorAccess policy attached. Sample policy below.

   {
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "*",
      "Resource": "*"
    }
  ]
}

   * Make sure your IAM role has following policies attached. AmazonRDSFullAccess, AmazonSQSFullAccess, AmazonElastiCacheFullAccess, AmazonS3FullAccess and AmazonSNSFullAccess.
   * SNS will be created at run time via SDK based on the provided user name.


| <img src="https://github.com/illinoistech-itm/bpatel68/blob/master/itmo-544/mp3/images/pic2.jpg" alt="" style="width: 400px;"/> |
|:--:| 
| *Sample o/p of create scripts 1* |

| <img src="https://github.com/illinoistech-itm/bpatel68/blob/master/itmo-544/mp3/images/pic3.jpg" alt="" style="width: 400px;"/> |
|:--:| 
| *Sample o/p of create scripts 2* |

### 4. Use the ELB url displayed on console to see the home page. Refer above Sample o/p of create scripts 2. It should be something like <ELB URL>:3000/messages. You will see a home page like below screenshot. There are no messages currently. First request may take sometime considering table creation taking place.

| <img src="https://github.com/illinoistech-itm/bpatel68/blob/master/itmo-544/mp3/images/pic4.jpg" alt="" style="width: 400px;"/> |
|:--:| 
| *Home page of the application* |


### 5. Click on Add Message button which will take you to a page something like shown below. All details are mandatory. I've done only mandatory validations hence, it is assumed you will provide only valid email id and phone (starting with country code 1). For ease I am defaulting my email id and phone number. You can replace your email id and phone number here. You will get a notification on mentioned details for your message completion. Once you provide your email id make sure you visit your mailbox and confirm the subscription. It may happen that confirm subscription takes time and the translation has been completed so you will receive only SMS and not an email. Input the message which you would like to translate to french. I have not tested the google translation API for huge text hence, I recommend to provide a single line of message. Like hello how are you or something like that.  Click on save button to submit the job for processing.


| <img src="https://github.com/illinoistech-itm/bpatel68/blob/master/itmo-544/mp3/images/pic8.jpg" alt="" style="width: 400px;"/> |
|:--:| 
| *Add New Message screen* |


### 6. After you click on save button, on success it will redirect you back to home page. Now, you will see there is a new message with status pending. Message UUID is a hyperlink which will take you to message details page but, only when the status of the message is completed. You will see a screen like below.


| <img src="https://github.com/illinoistech-itm/bpatel68/blob/master/itmo-544/mp3/images/pic9.jpg" alt="" style="width: 400px;"/> |
|:--:| 
| *Home screen with newly created message* |


### 7. The processing job will run every one minute and get one message at a time from SQS. Process it and update translated text in S3 and update status of the message as completed. You should get an SMS after the translation has been completed. After you get an SMS please refresh the home page. You will see the status as completed.

| <img src="https://github.com/illinoistech-itm/bpatel68/blob/master/itmo-544/mp3/images/pic14.jpg" alt="" style="width: 400px;"/> |
|:--:| 
| *Job completion notification SMS* |


| <img src="https://github.com/illinoistech-itm/bpatel68/blob/master/itmo-544/mp3/images/pic10.jpg" alt="" style="width: 400px;"/> |
|:--:| 
| *Home screen with status as completed* |


### 8. Click on the Message UUID hyper link of the message. It will take you to the message details page. You will see the translated text here.

| <img src="https://github.com/illinoistech-itm/bpatel68/blob/master/itmo-544/mp3/images/pic11.jpg" alt="" style="width: 400px;"/> |
|:--:| 
| *Message details page with translated text* |



### 9. Now, go back to home page by clicking home page button. There you will see a button named Admin Page which will take you to the Admin login page. Click on that button. You will see a screen like below. I've hardcoded username and password as admin/admin. Click on Login button.

| <img src="https://github.com/illinoistech-itm/bpatel68/blob/master/itmo-544/mp3/images/pic5.jpg" alt="" style="width: 400px;"/> |
|:--:| 
| *Admin login page* |


### 10. On successful login, it will redirect you to admin home page. You will see a screen something like below. User cannot visit this page directly without login. On login, I am setting a session which will be active for ten seconds. You can wait for around 15 seconds and try to refresh the page. It should take you back to login page if the session details are not available. The validation is same when user tries to access the admin home page directly via URL.

| <img src="https://github.com/illinoistech-itm/bpatel68/blob/master/itmo-544/mp3/images/pic12.jpg" alt="" style="width: 400px;"/> |
|:--:| 
| *Admin home page and Message gallery page* |


### 11. Notice this admin home page is a gallery page where message uuid along with original and translated text is visible. Refer above screenshot.

### 12. Now, you can click on Export Messages button which will download the DB dumb in a text file with CSV. Refer below screenshots.

| <img src="https://github.com/illinoistech-itm/bpatel68/blob/master/itmo-544/mp3/images/pic13.jpg" alt="" style="width: 400px;"/> |
|:--:| 
| *Export button with downloaded file* |

| <img src="https://github.com/illinoistech-itm/bpatel68/blob/master/itmo-544/mp3/images/pic15.jpg" alt="" style="width: 400px;"/> |
|:--:| 
| *Content of the txt file* |


### 13. Now, you will see a button named disable add messages. You can click on that button to disable the Add Message button on home page. After you have clicked the button go back to home page by clicking home page button. You will notice the button is disabled.


| <img src="https://github.com/illinoistech-itm/bpatel68/blob/master/itmo-544/mp3/images/pic6.jpg" alt="" style="width: 400px;"/> |
|:--:| 
| *Disable add message button on admin home page* |


| <img src="https://github.com/illinoistech-itm/bpatel68/blob/master/itmo-544/mp3/images/pic7.jpg" alt="" style="width: 400px;"/> |
|:--:| 
| *Disabled add message button on home page* |


### 14. You can visit the same admin home page to enable the add message button. This time you will notice the button text will be displayed as Enable Add Messages. This configuration is saved in database as well as elasticache. If the config is not available in cache then DB request will be done. The result will be also placed in cache for future.


### 15. After you have tested all functionality it's time to delete everything. Run destroy scripts to remove everything we created. You will see an o/p something like below screenshot on successful execution of delete script.

*./destroy-mp3.sh*

| <img src="https://github.com/illinoistech-itm/bpatel68/blob/master/itmo-544/mp3/images/pic16.jpg" alt="" style="width: 400px;"/> |
|:--:| 
| *Destroy script output 1* |

| <img src="https://github.com/illinoistech-itm/bpatel68/blob/master/itmo-544/mp3/images/pic18.jpg" alt="" style="width: 400px;"/> |
|:--:| 
| *Destroy script output 2* |

### Assumptions and Additional Notes

   * Execution is sequential for all scripts. If some command fails it will display error and terminate execution of script from that point without executing further commands.
   * Destroy script is assuming to delete everything leaving your AWS a clean slate.
   * There are wait commands in create and destroy scripts. If by any chance wait commands fails script execution will terminate with status code 255. You have to execute entire script again.
   * When formatting additional EBS in instance initialization script the time out is 10 minutes. So, if volume is not attached to the instance within 10 min. It will not be mounted.
   * Region is us-west-2 and availability zone is us-west-2b for everything.
   * DB name has been used as bhavin-mp2-db and bhavin-mp2-db-read (Read replica) in the application.
   * Everytime you create a new message there will be new subscription created based on the username provided.
   * I am using NodeJS AWS SDK for the application development.
   * Text translation job is not using read replica changes. Only UI is handled to use read replica for all select queries. Necessary code is commented for your reference. You can check comments "reading from replica" in server.js.
   * Additional table created named config which will save parameter to enable/disable add message button.
   * ElastiCache is used for caching enable/disable parameter. If it is available in cache it will be used from cache. If it is not available in cache then it will be fetched from DB and placed in cache for future.
   * Your very first request may take some additional time considering table creation taking place in DB.
   * Session management is done for Admin Home page. User cannot go to Admin Home Page without login. Credentials are hardcoded as admin/admin. Also, the session will be active for 10 seconds.
   * There is an export button on Admin home page which will download a txt file with all DB records having comma separated value.
   * Enable/disable button is on admin home page.
   * Admin home page is displaying gallery of messages in list.
   * Creating everything may take approx 15-20 minutes considering wait commands in place.