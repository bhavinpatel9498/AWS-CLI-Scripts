#!/bin/bash
###################

#Delete Launch configurations and Auto Scaling Group

autoGrpId=`aws autoscaling describe-auto-scaling-groups --auto-scaling-group-name bhavin-mp3-auto-scaling --output text`

if [ "$?" -ne "0" ]
then
	echo "No AutoScaling Group to delete"
else
	if [ ! -z "$autoGrpId" ]
	then
		echo "Delete Auto Scaling Group"
		
		aws autoscaling delete-auto-scaling-group --auto-scaling-group-name bhavin-mp3-auto-scaling --force-delete >/dev/null 2>&1
		
		if [ "$?" -ne "0" ]
		then
			echo "Either Auto Scaling Group is being deleted or pending. Try again in a while."
		else
			echo "Auto Scaling Group Deleted"
		fi
	
	else

		echo "No Auto Scaling Group to Delete"
	
	fi

fi



autoLaunchId=`aws autoscaling describe-launch-configurations --launch-configuration-names bhavin-mp3-launch-config --output text`

if [ "$?" -ne "0" ]
then
	echo "No Launch Config to delete"
else
	if [ ! -z "$autoLaunchId" ]
	then
		echo "Delete Launch Config"
		
		aws autoscaling delete-launch-configuration --launch-configuration-name bhavin-mp3-launch-config >/dev/null 2>&1
		
		if [ "$?" -ne "0" ]
		then
			echo "Either Launch Config is being deleted or pending. Try again in a while."
		else
			echo "Launch Config Deleted"
		fi
	
	else

		echo "No Launch Config to Delete"
	
	fi

fi


###################
loadBalancerList=`aws elb describe-load-balancers --query 'LoadBalancerDescriptions[*].LoadBalancerName' --output text`

if [ "$?" -ne "0" ]
then
	echo "Terminate Script"
	exit 1;
fi

if [ ! -z "$loadBalancerList" ]
then

	declare -a arrLoadBalancerList=(${loadBalancerList})
	# get length of an arrLoadBalancerList
	arrLoadBalancerListLength=${#arrLoadBalancerList[@]}
	
	for (( i=1; i<${arrLoadBalancerListLength}+1; i++ ));
	do	

		#Getting Load balancer instances

		InstanceIdList=`aws elb describe-load-balancers --load-balancer-name ${arrLoadBalancerList[$i-1]} --query 'LoadBalancerDescriptions[*].Instances' --output text`

		if [ "$?" -ne "0" ]
		then
			echo "Terminate Script"
			exit 1;
		fi

		echo "$InstanceIdList"

		############

		#Deregister Load Balancers instances

		if [ ! -z "$InstanceIdList" ]
		then
			echo "Deregister instances from load balancer"
			tempVar=`aws elb deregister-instances-from-load-balancer --load-balancer-name ${arrLoadBalancerList[$i-1]} --instances $InstanceIdList`
			
			if [ "$?" -ne "0" ]
			then
				echo "Terminate Script"
				exit 1;
			fi
			
			echo "Instances deregistered"
			
		fi

		############

		#Delete Load balancer

		echo "Delete load balancer"
		aws elb delete-load-balancer --load-balancer-name ${arrLoadBalancerList[$i-1]}

		if [ "$?" -ne "0" ]
		then
			echo "Terminate Script"
			exit 1;
		fi

		echo "Load balancer deleted"


		############

		#Delete Instances now


		if [ ! -z "$InstanceIdList" ]
		then
			echo "Terminating all instance."
			temploadbalinstance=`aws ec2 terminate-instances --instance-ids $InstanceIdList`
			
			if [ "$?" -ne "0" ]
			then
				echo "Terminate Script"
				exit 1;
			fi
			
			echo "Waiting for Instances to terminate"
			
			aws ec2 wait instance-terminated --instance-ids $InstanceIdList
			
			echo "All Instances Terminated"
		
		else
			
			echo "No instances to delete for Load balancer ${arrLoadBalancerList[$i-1]}"
			
		fi
	
	done

else
	
	echo "No Load Balancer to Delete"

fi
############

AllInstanceIdList=`aws ec2 describe-instances --filters '[{"Name": "instance-state-name","Values": ["pending", "running"] }]' --query 'Reservations[*].Instances[*].InstanceId' --output text`

if [ "$?" -ne "0" ]
then
	echo "Terminate Script"
	exit 1;
fi


if [ ! -z "$AllInstanceIdList" ]
then
	echo "Terminating other running instances"
	
	tempotherinstances=`aws ec2 terminate-instances --instance-ids $AllInstanceIdList`
	
	if [ "$?" -ne "0" ]
	then
		echo "Terminate Script"
		exit 1;
	fi	
	
	echo "Waiting for Instances to terminate"
	
	aws ec2 wait instance-terminated --instance-ids $AllInstanceIdList
	
	echo "All other Instances Terminated"
	
else

	echo "No Extra Instances running"

fi

############

#Deleting EBS Volumes

volumesList=`aws ec2 describe-volumes --filters '[{"Name":"tag:InstanceOwnerStudent","Values":["A20410380"]}, {"Name":"status", "Values":["available", "error", "creating"]}]' --query "Volumes[*].VolumeId" --output text`

if [ "$?" -ne "0" ]
then
	echo "Terminate Script"
	exit 1;
fi


if [ ! -z "$volumesList" ]
then

	echo "Deleting Volumes"

	declare -a arrVolumesList=(${volumesList})
	# get length of an arrVolumesList
	arrVolumesListLength=${#arrVolumesList[@]}

	
	for (( i=1; i<${arrVolumesListLength}+1; i++ ));
	do		
		aws ec2 delete-volume --volume-id ${arrVolumesList[$i-1]}
		
		if [ "$?" -ne "0" ]
		then
			echo "Terminate Script"
			exit 1;
		fi	
	done
	
	#Wait while all volumes are deleted
	
	aws ec2 wait volume-deleted --volume-ids $volumesList
	
	if [ "$?" -ne "0" ]
	then
		echo "Terminate Script"
		exit 1;
	fi	
	
	echo "Volumes Deleted"
	
else

	echo "No volumes to delete"
	
fi



############

#Delete S3 Bucket


bucketList=`aws s3api list-buckets --query "Buckets[].Name" --output text`

if [ "$?" -ne "0" ]
then
	echo "Terminate Script"
	exit 1;
fi

if [ ! -z "$bucketList" ]
then

	echo "Delete S3 Buckets"

	declare -a arrBucketList=(${bucketList})
	# get length of an arrVolumesList
	arrBucketListLength=${#arrBucketList[@]}

	#Getting Buckets
	for (( i=1; i<${arrBucketListLength}+1; i++ ));
	do		
		
		echo "Deleting objects for bucket ${arrBucketList[$i-1]}"
		
		objectList=`aws s3api list-objects-v2 --bucket ${arrBucketList[$i-1]} --query 'Contents[].Key' --output text`
		
		if [ "$?" -ne "0" ]
		then
			echo "Terminate Script"
			exit 1;
		fi	
		
		if [ ! -z "$objectList" ]
		then
			declare -a arrObjectList=(${objectList})
			# get length of an arrVolumesList
			arrObjectListLength=${#arrObjectList[@]}
			
			for (( j=1; j<${arrObjectListLength}+1; j++ ));
			do	
				#aws s3api delete-objects --bucket ${arrBucketList[$i-1]} --delete '{"Objects":[{"Key":"${arrObjectList[$j-1]}"}]}'>/dev/null 2>&1
				
				aws s3api delete-object --bucket ${arrBucketList[$i-1]} --key ${arrObjectList[$j-1]}>/dev/null 2>&1
				
				aws s3api wait object-not-exists --bucket ${arrBucketList[$i-1]} --key ${arrObjectList[$j-1]}
			
			done		
		fi
		
		echo "Objects Deleted"
		
		echo "Delete Bucket ${arrBucketList[$i-1]}"		
		
		aws s3api delete-bucket --bucket ${arrBucketList[$i-1]}

		if [ "$?" -ne "0" ]
		then
			echo "Terminate Script"
			exit 1;
		fi

		aws s3api wait bucket-not-exists --bucket ${arrBucketList[$i-1]}

		echo "Bucket Deleted"	
		
	done

else

	echo "No buckets to delete"
	
fi

############

#Delete SNS

echo "Delete SNS"

sublist=`aws sns list-subscriptions --query 'Subscriptions[*].SubscriptionArn' --output text`

if [ "$?" -ne "0" ]
then
	echo "Terminate Script"
	exit 1;
fi

if [ ! -z "$sublist" ]
then

	echo "Delete Subscriptions"

	declare -a arrsublist=(${sublist})
	# get length of an arrVolumesList
	arrsublistLength=${#arrsublist[@]}
	
	for (( i=1; i<${arrsublistLength}+1; i++ ));
	do			
		aws sns unsubscribe --subscription-arn ${arrsublist[$i-1]} > /dev/null 2>&1

	done
	
	echo "subscriptions deleted"

else

	echo "No subscriptions to delete"
	
fi

############

#Delete topics


topiclist=`aws sns list-topics --query 'Topics[*].TopicArn' --output text`

if [ "$?" -ne "0" ]
then
	echo "Terminate Script"
	exit 1;
fi

if [ ! -z "$topiclist" ]
then

	echo "Delete Topics"

	declare -a arrtopiclist=(${topiclist})
	# get length of an arrVolumesList
	arrtopiclistLength=${#arrtopiclist[@]}
	
	for (( i=1; i<${arrtopiclistLength}+1; i++ ));
	do			
		aws sns delete-topic --topic-arn ${arrtopiclist[$i-1]} > /dev/null 2>&1

	done
	
	echo "Topics deleted"

else

	echo "No Topics to delete"
	
fi


############

#Delete SQS

sqslist=`aws sqs list-queues --queue-name-prefix bpatel68-sqs-mp2-msg --query 'QueueUrls[*]' --output text`

if [ "$?" -ne "0" ]
then
	echo "Terminate Script"
	exit 1;
fi

if [ ! -z "$sqslist" ]
then

	echo "Delete SQS"

	declare -a arrsqslist=(${sqslist})
	# get length of an arrVolumesList
	arrsqslistLength=${#arrsqslist[@]}
	
	for (( i=1; i<${arrsqslistLength}+1; i++ ));
	do			
		aws sqs delete-queue --queue-url ${arrsqslist[$i-1]} > /dev/null 2>&1

	done
	
	echo "SQS deleted"

else

	echo "No SQS to delete"
	
fi


############

#Delete RDS

rdsval=`aws rds describe-db-instances --db-instance-identifier bhavin-mp2-db`

if [ "$?" -ne "0" ]
then
	echo "No RDS to delete"
else

	if [ ! -z "$rdsval" ]
	then
		
		aws rds delete-db-instance --db-instance-identifier bhavin-mp2-db-read --skip-final-snapshot >/dev/null 2>&1
		
		if [ "$?" -ne "0" ]
		then
			echo "Either RDS Read Reaplica is being deleted or pending. Try again in a while."
		else
			echo "RDS Read Replica Delete initiated"
		fi
		
		aws rds delete-db-instance --db-instance-identifier bhavin-mp2-db --skip-final-snapshot >/dev/null 2>&1
		
		if [ "$?" -ne "0" ]
		then
			echo "Either RDS is being deleted or pending. Try again in a while."
		else
			echo "RDS Delete initiated"
		fi			
	

	else

		echo "No RDS to delete"
	
	fi
	
fi



############

cacheVal=`aws elasticache describe-cache-clusters --cache-cluster-id bpatel68-mp3-cache`

if [ "$?" -ne "0" ]
then
	echo "No ElastiCache to delete"
else
	if [ ! -z "$cacheVal" ]
	then
	
		aws elasticache delete-cache-cluster --cache-cluster-id bpatel68-mp3-cache >/dev/null 2>&1
		
		if [ "$?" -ne "0" ]
		then
			echo "Either ElastiCache is being deleted or pending. Try again in a while."
		else
			echo "ElastiCache Delete initiated"
		fi
	
	else

		echo "No ElastiCache to Delete"
	
	fi

fi


############


echo "End of Destroy Script"



