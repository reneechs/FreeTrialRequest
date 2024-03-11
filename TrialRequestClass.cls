public class TrialRequestClass{
	public static void createDefaultTrialRequest(Map<Id, sObject> mapIds){
		List<TrialRequest__c> listTrial = new List<TrialRequest__c>();
		List<TrialRequest__c> lstDuplicateTR = [SELECT Id, Contact__c, Comments__c, Language__c FROM TrialRequest__c WHERE Type__c = 'Free Trial' AND Contact__c IN: mapIds.keySet() AND CreatedDate >=: (System.now() - 0.0003)];
		System.debug('DUPLICATE CHECK='+ lstDuplicateTR);
		if(lstDuplicateTR.size() > 0){
			for(Id id:mapIds.keySet()){
				for(TrialRequest__c t : lstDuplicateTR){ // Environ 1 minute
					if (t.Contact__c != id || (mapIds.get(id).get('ProductProjectType__c') != null && t.Comments__c != (String)mapIds.get(id).get('ProductProjectType__c')) || t.Language__c != (String)mapIds.get(id).get('TrialRequestLanguage__c')){						
					   listTrial.add(createTrialRequest(mapIds, id));
					}
				}
			}
		}
		else{
			for(Id id:mapIds.keySet()){
				if (mapIds.get(id).get('ProductProjectType__c') != null) 
					listTrial.add(createTrialRequest(mapIds, id));
			}
		}
		

		if(!listTrial.isEmpty()){
			try{
				insert listTrial;
			}
			catch(System.DMLException e){
				system.debug('*** ERROR While inserting Trial Request'+e);
			}
		}
	}

	private static  TrialRequest__c createTrialRequest(Map<Id, sObject> mapIds, ID id){
		TrialRequest__c tr = new TrialRequest__c();	
		tr.Type__c = 'Free Trial';
		tr.Contact__c = id;		
		tr.Comments__c = (String)mapIds.get(id).get('ProductProjectType__c');
		tr.Language__c = (String)mapIds.get(id).get('TrialRequestLanguage__c');
		return tr;
	}

}
