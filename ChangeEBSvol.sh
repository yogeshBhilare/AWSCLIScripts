[osboxes@ansible-controller ~]$ cat changeEBS.sh
#!/bin/bash

#input : $1 -- instance id  #input : $2-- volume id #input : $3 size of new volume
instanceid=$1
vid=$2
sz=$3

create_snapshot() {
aws ec2 create-snapshot --volume-id $vid  --description 'root backup' --tag-specifications 'ResourceType=snapshot,Tags=[{Key=purpose,Value=prod},{Key=costcenter,Value=123}]' > create_snaplog
snapid=$(cat create_snaplog|grep SnapshotId |cut -d: -f2|sed 's/\"//g;s/\,//g')
while [ $(aws ec2 describe-snapshots --snapshot-id $snapid --output table |grep completed|wc -l) -ne 1 ]
do
        echo "creating snapshot"
        sleep 30
done
}
create_volume(){
aws ec2 create-volume --volume-type gp2 --snapshot-id $1   --size $sz  --availability-zone ap-south-1a > createvollog
new_vol=$(cat createvollog|grep VolumeId |cut -d: -f2|sed 's/\"//g;s/\,//g')
while [ $(aws ec2 describe-volumes --volume-id $new_vol |grep available|wc -l) -ne 1 ]
do
        echo "creating volume"
        sleep 30
done
}
###########Main##############################3

create_snapshot
echo $snapid
create_volume $snapid
#stop instance
echo "Stopping instance"
aws ec2 stop-instances  --instance-id $instanceid >/dev/null

while [ $(aws ec2 describe-instances --instance-ids $instanceid --query 'Reservations[*].Instances[*].{st:State.Name}' --output table|grep stopped|wc -l) -lt 1 ]
do
        echo "instance is not stopped yet"
        sleep 30
done

#detach ol volume
echo "Detaching old volume"
aws ec2 detach-volume --volume-id $vid

#new Volume attached
echo "Attaching new volume"
aws ec2 attach-volume --volume-id $new_vol --instance-id  $instanceid --device /dev/xvda
sleep 20

#starting instance
aws ec2 start-instances > /dev/null --instance-id $instanceid
while [ $(aws ec2 describe-instances --instance-ids $instnaceid --query 'Reservations[*].Instances[*].{st:State.Name}' --output table|grep runn|wc -l) -ne 1 ]
do
        echo "checking status"
        sleep 10
done
echo "Instance started with new vol $new_vol"
