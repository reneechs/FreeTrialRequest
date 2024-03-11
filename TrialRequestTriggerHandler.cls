/***********************************************************************************************************************************
* @author           Renee chua
* @description      This Apex Class is used to update Free Trial Request for Customer using information generated from the webform.
************************************************************************************************************************************/

public class TrialRequestTriggerHandler {
       
/*********************************************************************************************
*@Description :  AfterInsert event on 'TrialRequest' sObject trigger this method                                                                                    
*********************************************************************************************/    

public override void afterInsert() {
	if( !TriggerFramework.isBypassed('TR_AFTER_INSERT') && trigger.isInsert && trigger.isAfter ){
		    
		Map<String,String> mapfieldname	= new Map<String, String>();
		List <String> Comments = new List<String>();
		List <TrialRequest__c> ListTrial = new List <TrialRequest__c> ();
		List<TrialRequest__c> lstNewTR = Trigger.new;
		List <TrialLogin__c> lstTRLogin = new List <TrialLogin__c> ();
		List<Environment__c> lst1 = new List <Environment__c> ();
		Map<String,User__c> mapusr	= new Map<String, User__c>();
		Set<ID> setTR = new Set<Id>();
		Set<ID> setCont = new Set<Id>();
		Set<ID> set = new Set<Id>();
		List<ID> TRIDs = new List<ID>(); 

				
		for (TrialRequest__c tr : lstNewTR) {

			If (tr.RecordTypeId == Class.ID_TRIAL_RT_STAND && (tr.Type__c == 'Free Trial' || tr.Type__c == 'POC' || tr.Type__c == 'Project') ) {
					
				String type='TrialRequest__c';

				Map<String, Schema.SObjectType> schemaMap = Schema.getGlobalDescribe();
				Schema.SObjectType leadSchema = schemaMap.get(type);
				Map<String, Schema.SObjectField> fieldMap = leadSchema.getDescribe().fields.getMap();

				//Retrieve label and fieldname of object
				for (String fieldName: fieldMap.keySet()) {
					string Label = fieldMap.get(fieldName).getDescribe().getLabel();
					mapfieldname.put(Label,fieldname);					
				}

				TrialRequest__c TRL = new TrialRequest__c (); 

				//Retrieve Username related to products
				List<User__c> lstUser = new List<User__c>([SELECT Id, Name, Products__c, Profile__c,Email__c,CurrencyIsoCode,CommandLine__c FROM User__c where Products__c <> null]);
				for (User__c usr1 : lstUser){
					List <String> pdt = new List<String>(usr1.products__c.split(';'));
					for (String pdt1 : pdt) {
						mapusr.put(pdt1.trim(),usr1);
					}
				}
				System.debug('****Usr Map='+mapusr);

				If (tr.Contact__c != null) {
					setCont.add(tr.Contact__c);

					List<Contact> lstContact = new List<Contact>([SELECT Id, Name, AccountId, Account.OwnerId, Account.ServicesDirector__c, Account.AccountOwnerSDR__c FROM Contact 
					    																	  WHERE Id IN : setCont]);					
					// Retrieve email receipients information from contact 
					If (lstContact.size() > 0) {
						for (Contact c : lstContact ){
							TRIDs.add(tr.id);
							TRL.Account__c = c.AccountId;
							TRL.SalesRepresentative__c = c.Account.OwnerId;
							TRL.ServicesDirector__c = c.Account.ServicesDirector__c;
							TRL.Account_SDR__c = c.Account.AccountOwnerSDR__c;
						}
					}
				}

				If (tr.Type__c == 'Free Trial' && tr.Comments__c != null) {

					List<Environment__c> lst = new List<Environment__c>([SELECT Id, Name, Status__c, Version__c, Server__r.Name, Server__r.Version__r.Name , Server__r.Version__r.CreatedDate, Password__c FROM Environment__c 
																							  WHERE Status__c = 'FREE' AND Server__r.Status__c = 'UP' AND Server__r.Platform__c = 'Free Trial' order by Server__r.Version__r.Release_date__c DESC LIMIT 1]);					
					If (lst.size() > 0) {
						TRL.Environment__c = lst[0].Id;						
						Set.add(lst[0].Id); 
					}
					System.debug('*** environment Set ' + Set + tr.id);	

					//To resolve issue of same  Environment assigned to 2 prospect
					for (Environment__c  : [SELECT Id, Name, Free_Trial_Request_Closed__c, Status__c FROM Environment__c  WHERE Id IN: Set]) {
						.Status__c = 'BUSY';
						.Free_Trial_Request_Closed__c = false;
						lst1.add();
					}	
					System.debug('*** environment lst1' + lst1);		

					//Retrieve comments that stores products selected delimited by ';' into individual strings
					Comments = tr.Comments__c.split(';');
					System.debug('##Comments List='+Comments);// list of all field API name

					//Compare each comments string with mapfieldname and assigned it to true if there is a match
					If (mapusr.size() > 0) {	
						for (string str1 : Comments) {		
							str1 = str1.trim();	
							If (mapfieldname.containsKey(str1)){					
								TRL.Id = tr.Id;			
								TRL.put(mapfieldname.get(str1),true);	
										
								//Create Trial login of each product with username extracted from  User object
								for (string str2 : mapusr.keySet()) {
									if (str2 == str1) {
										TrialLogin__c TrLogin = new TrialLogin__c ();
										TrLogin.User__c = mapusr.get(str2).Id;
										TrLogin.TrialRequest__c = tr.Id;
										TrLogin.CustomUserName__c = mapusr.get(str2).Name;
										TrLogin.Language__c = tr.Language__c;
										TrLogin.Profile__c = mapusr.get(str2).Profile__c;
										TrLogin.Email__c = mapusr.get(str2).Email__c;
										TrLogin.CurrencyIsoCode = mapusr.get(str2).CurrencyIsoCode;
										TrLogin.CommandLine__c = mapusr.get(str2).CommandLine__c;
										lstTRLogin.add(TRLogin);
										System.debug('####TRLogin='+TRLogin);
									}
								}
							}																											
						}
					}
					
					//Revert Free trial to approval process
					If (lstTRLogin.size() > 0 && lst.size() > 0 && tr.Status__c == 'Draft') {		
						TRL.EndDate__c = tr.StartDate__c + 30;
					}

					ListTrial.add(TRL);
					SetTR.add(tr.Id); 
						
			}
															
		}
		TriggerFramework.bypass('TR_AFTER_UPDATE');
	}
			
	// Update the lists into system 
	if (ListTrial.size() > 0){
		try {
			update ListTrial;
		} 
		catch (system.Dmlexception e) {
			system.debug ('**Exception for TrialRequest Insert for  item ' + e);
		}

		if(lstTRLogin.size() > 0){
			try {
				insert lstTRLogin;
			} 
			catch (system.Dmlexception e) {
				system.debug ('**Exception for Trial Login Insert for  item ' + e);
			}
		}

		If (lst1.size() > 0) {
			try {
				update lst1;
			} 
			catch (system.Dmlexception e) {
				system.debug ('**Exception for  Environment ' + e);
			}				
		}

		if(TRIDs.size() > 0) { 
			TrialRequestClass.updateOwnership(TRIDs,setCont); 
		} 
				
		// Auto approval process submission
		if (setTR.size() > 0) {
			List <TrialRequest__c> lstTR = new List <TrialRequest__c> ([Select Id, Type__c from TrialRequest__c where Id IN: setTR]); 
				
			for(TrialRequest__c tr1 : lstTR){	
				if (tr1.Type__c	== 'Free Trial') { 		
					Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
					req.setObjectId(tr1.id);
					List <User> SF = New List <User>([Select Id from User where Name = 'Salesforce Admin' limit 1]);
					If (SF.size() > 0) 
						req.setSubmitterId(SF[0].Id);
					Approval.ProcessResult result =  Approval.process(req);		
					System.debug('TEST SUBMIT');			
				}
				}
			}
		}	

	}
}

/*********************************************************************************************
*@Description : AfterUpdate event on 'TrialRequest' sObject trigger this method                                                                                 
*********************************************************************************************/    
	
    public override void afterUpdate() {
        if( !TriggerFramework.isBypassed('TR_AFTER_UPDATE') && trigger.isUpdate && trigger.isAfter ){
			
            String sTRStatusApp = UtilityClass.getPickListValues(TrialRequest__c.Status__c.getDescribe(), 'Approved');
            String sTRStatusRej = UtilityClass.getPickListValues(TrialRequest__c.Status__c.getDescribe(), 'Rejected');
			String sTRStatusSub = UtilityClass.getPickListValues(TrialRequest__c.Status__c.getDescribe(), 'Submitted');
            List<TrialRequest__c> lstNewTR = Trigger.new;
            Map<Id,TrialRequest__c> mapOldTR = (Map<Id,TrialRequest__c>) Trigger.oldMap;
            Set<ID> setTTRejec = new Set<Id>();
            Set<ID> setTTApprov = new Set<Id>();
			Set<ID> setSTR = new Set<Id>();
			Set<ID> setTR = new Set<Id>();
			Set<ID> setUser = new Set<Id>();
			Set<ID> set = new Set<Id>();
			Map<String,String> mapfieldname	= new Map<String, String>();
			List <String> Comments = new List<String>();
			List <TrialRequest__c> ListTrial = new List <TrialRequest__c> ();
			List <TrialLogin__c> lstLoginAdd = new List <TrialLogin__c> ();
			List <TrialLogin__c> lstLoginDel = new List <TrialLogin__c> ();
			List <TrialLogin__c> lstLoginChg = new List <TrialLogin__c> ();
			List<Environment__c> lst = new List <Environment__c> ();
			List<Id> lstEnvId = new List <Id>();
			Map<String,User__c> mapusr	= new Map<String, User__c>();


			for (TrialRequest__c tr : lstNewTR) {

			
				If ( (checkRecursive.runOnce() || test.isRunningTest()) && tr.RecordTypeId == Class.ID_TRIAL_RT_STAND && (tr.Type__c == 'Free Trial' || tr.Type__c == 'POC' || tr.Type__c == 'Project')) {

					String type='TrialRequest__c';

					Map<String, Schema.SObjectType> schemaMap = Schema.getGlobalDescribe();
					Schema.SObjectType leadSchema = schemaMap.get(type);
					Map<String, Schema.SObjectField> fieldMap = leadSchema.getDescribe().fields.getMap();

					//Retrieve label and fieldname of object
					for (String fieldName: fieldMap.keySet()) {
						
						string Label = fieldMap.get(fieldName).getDescribe().getLabel();
						
						mapfieldname.put(Label,fieldname);					
					}
					
					//Retrieve Username related to products
					List<User__c> lstUser = new List<User__c>([SELECT Id, Name, Products__c, Profile__c,Email__c,CurrencyIsoCode,CommandLine__c FROM User__c where Products__c <> null]);
					for (User__c usr1 : lstUser){
						List <String> pdt = new List<String>(usr1.products__c.split(';'));
						for (String pdt1 : pdt) {
							mapusr.put(pdt1.trim(),usr1);
						}
					}
					
					
					SetTR.add(tr.Id);     
					 
					TrialRequest__c TRL = new TrialRequest__c (); 													
					If(mapusr.size() > 0) {	
						for (string str1 : mapusr.keySet()) {	
							if (mapfieldname.get(str1) != null) {
								
								//compare current and old values of product matched with fieldname. If not the same, set to false. If same, set to true
								boolean curvalue = (boolean)tr.get(mapfieldname.get(str1));
								boolean oldvalue = (boolean)mapOldTR.get(tr.Id).get(mapfieldname.get(str1));
							
								//Create new trial login 
								If (mapfieldname.containsKey(str1)) {
									If (curvalue != oldvalue) {	
										If (curvalue == true) {					
											TRL.Id = tr.Id;			
											TRL.put(mapfieldname.get(str1),true);	
											TrialLogin__c TrLogin = new TrialLogin__c ();
											TrLogin.User__c = mapusr.get(str1).Id;
											TrLogin.TrialRequest__c = tr.Id;
											TrLogin.CustomUserName__c = mapusr.get(str1).Name;
											TrLogin.Language__c = tr.Language__c;
											TrLogin.Profile__c = mapusr.get(str1).Profile__c;
											TrLogin.Email__c = mapusr.get(str1).Email__c;
											TrLogin.CurrencyIsoCode = mapusr.get(str1).CurrencyIsoCode;
											TrLogin.CommandLine__c = mapusr.get(str1).CommandLine__c;
											lstLoginAdd.add(TRLogin);
											
										}
										else {		
											//delete existing trial login that is not longer matching 					
											TRL.Id = tr.Id;			
											TRL.put(mapfieldname.get(str1),false);	
											List <TrialLogin__c> lstLogin = [select Id, CustomUserName__c from TrialLogin__c where TrialRequest__c IN : SetTR];
											for (TrialLogin__c TRLog : lstLogin) {
												If (TRLog.CustomUserName__c == mapusr.get(str1).Name) {
													lstLoginDel.add(TRLog);
												}
											}
										
										}
									}

								}
							}
						}																											
					}
															
					if(lstLoginAdd.size() > 0 || lstLoginDel.size() > 0)
						ListTrial.add(TRL);
                } 
				 

		// FOR TRIAL REQUEST WITH 'APPROVED' status AND "Standard Trial" type
		else 
			if( (tr.Type__c == 'POC' && tr.Status__c == sTRStatusApp && tr.RecordTypeId == Class.ID_TRIAL_RT_STAND && tr.POC_T_C_Accepted__c == true && mapOldTR.get(tr.Id).POC_T_C_Accepted__c == false) || 
				((tr.Type__c == 'Free Trial' || tr.Type__c == 'Project') && tr.Status__c == sTRStatusApp && mapOldTR.get(tr.Id).Status__c != sTRStatusApp && tr.RecordTypeId == Class.ID_TRIAL_RT_STAND) ) {
					setSTR.add(tr.Id); 
			}
			else 
			if (tr.Type__c == 'Free Trial' && tr.RecordTypeId == Class.ID_TRIAL_RT_STAND) {
						
				if (tr.Status__c == sTRStatusRej && mapOldTR.get(tr.Id).Status__c != sTRStatusRej) {
						
					If (tr.Environment__c != null) {
						set.add(tr.Environment__c);
						lstEnvId.add(tr.Environment__c);

						for (Environment__c  : [SELECT Id, Name, Free_Trial_Request_Closed__c, Status__c FROM Environment__c  WHERE Id IN: Set]) {
							.Status__c = 'FREE';
							.Free_Trial_Request_Closed__c = True;
								
								lst.add();
								System.debug('*** environment after rejection ' + lst);
							}
						}
					}
					// To reassign  Env after resubmission
					else 
						if (tr.Status__c == sTRStatusSub && mapOldTR.get(tr.Id).Status__c == sTRStatusRej) {
							List<Environment__c> lst1 = new List<Environment__c>([SELECT Id, Name, Status__c, Version__c, Server__r.Name, Server__r.Version__r.Name , Server__r.Version__r.CreatedDate, Password__c FROM Environment__c 
																								  WHERE Status__c = 'FREE' AND Server__r.Status__c = 'UP' AND Server__r.Platform__c = 'Free Trial' order by Server__r.Version__r.Release_date__c DESC LIMIT 1]);					
							If (lst1.size() > 0) {
								TrialRequest__c TR1 = new TrialRequest__c (); 	
								TR1.id = tr.Id;
								TR1.Environment__c = lst1[0].Id;
								Set.add(lst1[0].Id); 
								ListTrial.add(TR1);
							}
							System.debug('*** environment Set after resubmission ' + Set + tr.id);	

							for (Environment__c  : [SELECT Id, Name, Free_Trial_Request_Closed__c, Status__c FROM Environment__c  WHERE Id IN: Set]) {
								.Status__c = 'BUSY';
								.Free_Trial_Request_Closed__c = false;
								lst.add();
							}	
							System.debug('*** environment lst after resubmission' + lst);	
								
							for (TrialLogin__c TRL1 : [SELECT Id, Password__c FROM TrialLogin__c  WHERE TrialRequest__c IN: setTR]) {
								TRL1.Password__c = lst1[0].Password__c;
								lstLoginChg.add(TRL1);
							}
							System.debug('*** environment lst after resubmission' + lst);		

						}
			        }

            }

		// FREE TRIAL PROJECT UPDATE BEGIN
		if(ListTrial.size() > 0){
			try {
				update ListTrial;
			} 
			catch (system.Dmlexception e) {
				system.debug ('**Exception for TrialRequest Update  ' + e);
			}

			if(lstLoginAdd.size() > 0){
				try {
					insert lstLoginAdd;
				} 
				catch (system.Dmlexception e) {
					system.debug ('**Exception for Trial Login Create  ' + e);
				}
			} 

			if (lstLoginDel.size() > 0){
				try {
					delete lstLoginDel;
				} 
				catch (system.Dmlexception e) {
					system.debug ('**Exception for Trial Login Delete  ' + e);
				}
			}
			// FREE TRIAL PROJECT UPDATE END
		}
			
		If (lst.size() > 0) {
			try {
				update lst;
			} 
			catch (system.Dmlexception e) {
				system.debug ('**Exception for  Environment after rejection or resubmission' + e);
			}				
		}

		If (lstLoginChg.size() > 0) {
			try {
				update lstLoginChg;
			} 
			catch (system.Dmlexception e) {
				system.debug ('**Exception for Trial Login after resubmission' + e);
			}				
		}

		try{

			//Call EmailTemplate class to prepare email notification to be sent to customer/prospect
	
                	if(setSTR != null && setSTR.size() > 0){
                    EmailTemplateClass.prepareBulkUpdate(UtilityClass.getTrialLogin(setSTR));
                }

            }
            catch(Exception e){ lstNewTR[0].addError('Trigger afterUpdate on TrialRequest__c : Exception at line number = ' + e.getLineNumber() + ', Error message = ' + e.getMessage()); }
        }
    }
}
