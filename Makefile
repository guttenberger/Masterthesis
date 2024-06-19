include deployment/tf_env_vars.sh

init:
	@cd deployment && terraform init

deploy:
	@cd deployment && terraform apply

destroy:
	@cd deployment && terraform destroy

output-details:
	@cd deployment && terraform output hdinsight_cluster_details

destroy-force:
	for id in $$(az resource list --resource-group AlexGuttenberger_Thesis --query "[].id" -o tsv); \
	do \
		az resource delete --ids $$id --no-wait; \
	done
	rm -f deployment/terraform.tfstate*

# ANSIBLE COMMANDS

submit:
	ansible-playbook -i hibench/hosts.ini hibench/main.yml -e "number_of_workers=4 hibench_data_size=small"

setup:
	ansible-playbook -i hibench/hosts.ini hibench/setup-hibench.yml

ping:
	ansible all -i hibench/hosts.ini -m ping

# SSH COMMANDS

ssh:
	ssh $$SSH_USERNAME@$$SSH_ENDPOINT

ssh-wn0:
	ssh $$SSH_USERNAME@$$WN0_ADDRESS 

upload:
	scp -r $(DIR) $$SSH_USERNAME@$$SSH_ENDPOINT:/home/$$SSH_USERNAME
