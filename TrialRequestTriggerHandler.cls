/***********************************************************************************************************************************
* @author           Renee chua
* @description      This Apex Class is used to update Free Trial Request for Customer using information generated from the webform.
************************************************************************************************************************************/

public class TrialRequestTriggerHandler {
    
	/*********************************************************************************************
	*@Description : beforeInsert event on 'TrialRequest' sObject trigger this method                                                                            
	*********************************************************************************************/    

    public override void beforeInsert() {
        if( !MEGATriggerFramework.isBypassed('TR_BEFORE_INSERT') && trigger.isInsert && trigger.isBefore ){
            List<TrialRequest__c> lstNewTR				= Trigger.new;
			List<TrialRequest__c> lstTRTT				= new List<TrialRequest__c>();
			List<Event> lstEvt							= new List<Event>();
			Map<ID, ID> mapCHPV							= new Map<ID, ID>();
			Date dMinSD									= Date.today().addYears(1);
			Date dMaxED									= Date.today();
			PageReference prError						= null;
	
			
		
			// GET MIN Start Date & MAX Last Date
			try{
				for (TrialRequest__c tr : lstNewTR) {
					if(tr.RecordTypeId == MEGAClass.ID_TRIAL_RT_TRAIN){
						mapCHPV.put(tr.Campaign__c, tr.HopexProductVersion__c);
						dMinSD = (dMinSD >= tr.StartDate__c ? tr.StartDate__c - 1 : dMinSD);
						dMaxED = (dMaxED <= tr.EndDate__c ? tr.EndDate__c.addDays(1) : dMaxED);
						tr.NumberOfTrainees__c = 10;
						tr.NumberOfTrainers__c = 1;
						lstTRTT.add(tr);
					}
					
					/* REF-1838 RCA 17032020 Remove coding relating to Mega environment, Hopex Repository parameter and Data Center fields		
					if(lstTRTT.size() > 0){
						// Get Events which happen at the same time than Training Trial Request
						lstEvt = [SELECT Id, StartDateTime, EndDateTime, ShowAs, WhatId FROM Event WHERE OwnerId =:Label.CalendarTrainingEnvID  AND ((StartDateTime >= :dMinSD AND StartDateTime <= :dMaxED) OR (EndDateTime <= :dMaxED AND EndDateTime >= :dMinSD))];

				
						TrialRequestClass.SetMEGAEnvOnTrialFromAvailableServer(lstTRTT, lstEvt);

						if(mapCHPV != null && mapCHPV.size() > 0)
							TrialRequestClass.SetHopexReposParamOnTrialFromCamp(mapCHPV, lstTRTT);
					}
					*/
				}
			}
			catch(Exception e){ lstNewTR[0].addError('Trigger beforeInsert on TrialRequest__c : Exception at line number = ' + e.getLineNumber() + ', Error message = ' + e.getMessage()); }
				
	    }
    }
	/*********************************************************************************************
	*@Description :  AfterInsert event on 'TrialRequest' sObject trigger this method                                                                                    
	*********************************************************************************************/    

    public override void afterInsert() {
		if( !MEGATriggerFramework.isBypassed('TR_AFTER_INSERT') && trigger.isInsert && trigger.isAfter ){
		    
			Map<String,String> mapfieldname	= new Map<String, String>();
			List <String> Comments = new List<String>();
			List <TrialRequest__c> ListTrial = new List <TrialRequest__c> ();
			List<TrialRequest__c> lstNewTR = Trigger.new;
			List <TrialLogin__c> lstTRLogin = new List <TrialLogin__c> ();
			List<MEGAEnvironment__c> lstMega1 = new List <MEGAEnvironment__c> ();
			Map<String,MEGAUser__c> mapusr	= new Map<String, MEGAUser__c>();
			Set<ID> setTR = new Set<Id>();
			Set<ID> setCont = new Set<Id>();
			Set<ID> setMega = new Set<Id>();
			List<ID> TRIDs = new List<ID>(); 

				
			for (TrialRequest__c tr : lstNewTR) {

				/* RCA 2019-11-20 REF-1797 FREE TRIAL PROJECT */
				If (tr.RecordTypeId == MEGAClass.ID_TRIAL_RT_STAND && (tr.Type__c == 'Free Trial' || tr.Type__c == 'POC' || tr.Type__c == 'Project') ) {
					
					String type='TrialRequest__c';

					Map<String, Schema.SObjectType> schemaMap = Schema.getGlobalDescribe();
					Schema.SObjectType leadSchema = schemaMap.get(type);
					Map<String, Schema.SObjectField> fieldMap = leadSchema.getDescribe().fields.getMap();

					for (String fieldName: fieldMap.keySet()) {
						string Label = fieldMap.get(fieldName).getDescribe().getLabel();//It provides to get the object fields label.
						mapfieldname.put(Label,fieldname);					
					}

					TrialRequest__c TRL = new TrialRequest__c (); 
					
					List<MEGAUser__c> lstUser = new List<MEGAUser__c>([SELECT Id, Name, Products__c, MEGAProfile__c,Email__c,CurrencyIsoCode,CommandLine__c FROM MEGAUser__c where Products__c <> null]);
					for (MEGAUser__c usr1 : lstUser){
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
					
						If (lstContact.size() > 0) {
							for (Contact c : lstContact ){
								//TRL.OwnerId = c.Account.OwnerId;
								TRIDs.add(tr.id);
								TRL.Account__c = c.AccountId;
								TRL.SalesRepresentative__c = c.Account.OwnerId;
								TRL.ServicesDirector__c = c.Account.ServicesDirector__c;
								//REF-2035 RCA 5-5-20 To add in Account SDR
								TRL.Account_SDR__c = c.Account.AccountOwnerSDR__c;
							}
						}
					}

					If (tr.Type__c == 'Free Trial' && tr.Comments__c != null) {

							List<MEGAEnvironment__c> lstMega = new List<MEGAEnvironment__c>([SELECT Id, Name, Status__c, Version__c, Server__r.Name, Server__r.Version__r.Name , Server__r.Version__r.CreatedDate, Password__c FROM MEGAEnvironment__c 
																							  WHERE Status__c = 'FREE' AND Server__r.Status__c = 'UP' AND Server__r.Platform__c = 'Free Trial' order by Server__r.Version__r.Release_date__c DESC LIMIT 1]);					
							If (lstMega.size() > 0) {
								TRL.MEGAEnvironment__c = lstMega[0].Id;
								//TRL.Free_Trial_Password__c = lstMega[0].Password__c;
								SetMega.add(lstMega[0].Id); 
							}
							System.debug('***MEGA environment SetMega ' + SetMega + tr.id);	

							//*REF-2012 7-May-20 RCA To resolve issue of same Mega Environment assigned to 2 prospect
							for (MEGAEnvironment__c Mega : [SELECT Id, Name, Free_Trial_Request_Closed__c, Status__c FROM MEGAEnvironment__c  WHERE Id IN: SetMega]) {
								Mega.Status__c = 'BUSY';
								Mega.Free_Trial_Request_Closed__c = false;
								lstMega1.add(Mega);
							}	
							System.debug('***MEGA environment lstMega1' + lstMega1);		

							Comments = tr.Comments__c.split(';');
							System.debug('##Comments List='+Comments);// list of all field API name

						
							If (mapusr.size() > 0) {	
								for (string str1 : Comments) {		
									str1 = str1.trim();	
									If (mapfieldname.containsKey(str1)){					
										TRL.Id = tr.Id;			
										TRL.put(mapfieldname.get(str1),true);	
																																								
										for (string str2 : mapusr.keySet()) {
											if (str2 == str1) {
												TrialLogin__c TrLogin = new TrialLogin__c ();
												TrLogin.MEGAUser__c = mapusr.get(str2).Id;
												TrLogin.TrialRequest__c = tr.Id;
												TrLogin.CustomUserName__c = mapusr.get(str2).Name;
												TrLogin.Language__c = tr.Language__c;
												TrLogin.MEGAProfile__c = mapusr.get(str2).MEGAProfile__c;
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
					
							//REF-2035 RCA 5-5-20 Revert Free trial to approval process
							If (lstTRLogin.size() > 0 && lstMega.size() > 0 && tr.Status__c == 'Draft') {
								//TRL.Status__c = 'Approved'; 
								TRL.EndDate__c = tr.StartDate__c + 30;
							}

							ListTrial.add(TRL);
							SetTR.add(tr.Id); 
						
					}
					else If (tr.type__c == 'POC' || tr.Type__c == 'Project') {
						If(mapusr.size() > 0) {	
							for (string str1 : mapusr.keySet()) {								
								If (mapfieldname.containsKey(str1)) {
									boolean curvalue = (boolean)tr.get(mapfieldname.get(str1));
									If (curvalue == true) {					
										TRL.Id = tr.Id;			
										TRL.put(mapfieldname.get(str1),true);	
										TrialLogin__c TrLogin = new TrialLogin__c ();
										TrLogin.MEGAUser__c = mapusr.get(str1).Id;
										TrLogin.TrialRequest__c = tr.Id;
										TrLogin.CustomUserName__c = mapusr.get(str1).Name;
										TrLogin.Language__c = tr.Language__c;
										TrLogin.MEGAProfile__c = mapusr.get(str1).MEGAProfile__c;
										TrLogin.Email__c = mapusr.get(str1).Email__c;
										TrLogin.CurrencyIsoCode = mapusr.get(str1).CurrencyIsoCode;
										TrLogin.CommandLine__c = mapusr.get(str1).CommandLine__c;
										lstTRLogin.add(TRLogin);
										System.debug('####TRLoginPOC='+lstTRLogin);
									}
								}
							}
						}	
						ListTrial.add(TRL);																										
					}
															
				}
				MEGATriggerFramework.bypass('TR_AFTER_UPDATE');
			}
					
			if (ListTrial.size() > 0){
				try {
					update ListTrial;
				} 
				catch (system.Dmlexception e) {
					system.debug ('**Exception for TrialRequest Insert for Hopex item ' + e);
				}

				if(lstTRLogin.size() > 0){
					try {
						insert lstTRLogin;
					} 
					catch (system.Dmlexception e) {
						system.debug ('**Exception for Trial Login Insert for Hopex item ' + e);
					}
				}

				If (lstMega1.size() > 0) {
					try {
						update lstMega1;
					} 
					catch (system.Dmlexception e) {
						system.debug ('**Exception for Mega Environment ' + e);
					}				
				}

				if(TRIDs.size() > 0) { 
					TrialRequestClass.updateOwnership(TRIDs,setCont); 
				} 
				
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

			/*REF-2035 RCA 5-5-20 Revert Free trial to approval process
			if(setTR != null && setTR.size() > 0){
				EmailTemplateClass.prepareBulkUpdate(UtilityClass.getTrialLogin(setTR));
			} */
		}
	}
	/*********************************************************************************************
	*@Description : AfterUpdate event on 'TrialRequest' sObject trigger this method                                                                                 
	*********************************************************************************************/    
	
    public override void afterUpdate() {
        if( !MEGATriggerFramework.isBypassed('TR_AFTER_UPDATE') && trigger.isUpdate && trigger.isAfter ){
			
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
			Set<ID> setMega = new Set<Id>();
			Map<String,String> mapfieldname	= new Map<String, String>();
			List <String> Comments = new List<String>();
			List <TrialRequest__c> ListTrial = new List <TrialRequest__c> ();
			List <TrialLogin__c> lstLoginAdd = new List <TrialLogin__c> ();
			List <TrialLogin__c> lstLoginDel = new List <TrialLogin__c> ();
			List <TrialLogin__c> lstLoginChg = new List <TrialLogin__c> ();
			List<MEGAEnvironment__c> lstMega = new List <MEGAEnvironment__c> ();
			List<Id> lstEnvId = new List <Id>();
			Map<String,MEGAUser__c> mapusr	= new Map<String, MEGAUser__c>();


			for (TrialRequest__c tr : lstNewTR) {


				/* RCA 2019-11-20 REF-1797 FREE TRIAL PROJECT BEGIN*/				
				If ( (checkRecursive.runOnce() || test.isRunningTest()) && tr.RecordTypeId == MEGAClass.ID_TRIAL_RT_STAND && (tr.Type__c == 'Free Trial' || tr.Type__c == 'POC' || tr.Type__c == 'Project')) {

					String type='TrialRequest__c';

					Map<String, Schema.SObjectType> schemaMap = Schema.getGlobalDescribe();
					Schema.SObjectType leadSchema = schemaMap.get(type);
					Map<String, Schema.SObjectField> fieldMap = leadSchema.getDescribe().fields.getMap();

					for (String fieldName: fieldMap.keySet()) {
						//System.debug('##Field API Name='+fieldName);// list of all field API name
						string Label = fieldMap.get(fieldName).getDescribe().getLabel();//It provides to get the object fields label.
						//System.debug('##Field Label ='+Label);// list of all field API name
						mapfieldname.put(Label,fieldname);					
					}
											
					List<MEGAUser__c> lstUser = new List<MEGAUser__c>([SELECT Id, Name, Products__c, MEGAProfile__c,Email__c,CurrencyIsoCode,CommandLine__c FROM MEGAUser__c where Products__c <> null]);
					for (MEGAUser__c usr1 : lstUser){
						List <String> pdt = new List<String>(usr1.products__c.split(';'));
						for (String pdt1 : pdt) {
							mapusr.put(pdt1.trim(),usr1);
						}
					}
					//System.debug('****Usr Map After Update='+mapusr.keySet());
					
					SetTR.add(tr.Id);     
					 
					TrialRequest__c TRL = new TrialRequest__c (); 													
					If(mapusr.size() > 0) {	
						for (string str1 : mapusr.keySet()) {	
							if (mapfieldname.get(str1) != null) {
								//System.debug('Current value***='+tr.get(mapfieldname.get(str1)));
								//System.debug('Old value***='+mapOldTR.get(tr.Id).get(mapfieldname.get(str1)));
								boolean curvalue = (boolean)tr.get(mapfieldname.get(str1));
								boolean oldvalue = (boolean)mapOldTR.get(tr.Id).get(mapfieldname.get(str1));
							
								If (mapfieldname.containsKey(str1)) {
									If (curvalue != oldvalue) {	
										If (curvalue == true) {					
											TRL.Id = tr.Id;			
											TRL.put(mapfieldname.get(str1),true);	
											TrialLogin__c TrLogin = new TrialLogin__c ();
											TrLogin.MEGAUser__c = mapusr.get(str1).Id;
											TrLogin.TrialRequest__c = tr.Id;
											TrLogin.CustomUserName__c = mapusr.get(str1).Name;
											TrLogin.Language__c = tr.Language__c;
											TrLogin.MEGAProfile__c = mapusr.get(str1).MEGAProfile__c;
											TrLogin.Email__c = mapusr.get(str1).Email__c;
											TrLogin.CurrencyIsoCode = mapusr.get(str1).CurrencyIsoCode;
											TrLogin.CommandLine__c = mapusr.get(str1).CommandLine__c;
											lstLoginAdd.add(TRLogin);
											//System.debug('####TRLoginAdd='+lstLoginAdd);
										}
										else {							
											TRL.Id = tr.Id;			
											TRL.put(mapfieldname.get(str1),false);	
											List <TrialLogin__c> lstLogin = [select Id, CustomUserName__c from TrialLogin__c where TrialRequest__c IN : SetTR];
											for (TrialLogin__c TRLog : lstLogin) {
												If (TRLog.CustomUserName__c == mapusr.get(str1).Name) {
													lstLoginDel.add(TRLog);
												}
											}
											//System.debug('####TRLoginDel='+lstLoginDel);
										}
									}

								}
							}
						}																											
					}
															
					if(lstLoginAdd.size() > 0 || lstLoginDel.size() > 0)
						ListTrial.add(TRL);

                } /* RCA 2019-11-20 REF-1797 FREE TRIAL PROJECT END*/
				 
                /* FOR TRIAL REQUEST WITH 'APPROVED' status AND "Training Trial" type HHI 070218 Removed on Training Team demand (Send Manually)
                if(tr.Status__c == sTRStatusApp && mapOldTR.get(tr.Id).Status__c != sTRStatusApp && tr.RecordTypeId == MEGAClass.ID_TRIAL_RT_TRAIN)
                    setTTApprov.add(tr.Id);
				else */
				if(tr.Status__c == sTRStatusRej && mapOldTR.get(tr.Id).Status__c != sTRStatusRej && tr.RecordTypeId == MEGAClass.ID_TRIAL_RT_TRAIN)
					setTTRejec.add(tr.Id);

				// FOR TRIAL REQUEST WITH 'APPROVED' status AND "Standard Trial" type
				/*RCA 25-02-2019 REF-1182 To launch email only if PoC_Terms_and_Conditions_Accepted__c = true 
				else if(tr.Status__c == sTRStatusApp && mapOldTR.get(tr.Id).Status__c != sTRStatusApp && tr.RecordTypeId == MEGAClass.ID_TRIAL_RT_STAND) */
				else 
					if( (tr.Type__c == 'POC' && tr.Status__c == sTRStatusApp && tr.RecordTypeId == MEGAClass.ID_TRIAL_RT_STAND && tr.POC_T_C_Accepted__c == true && mapOldTR.get(tr.Id).POC_T_C_Accepted__c == false) || 
				         ((tr.Type__c == 'Free Trial' || tr.Type__c == 'Project') && tr.Status__c == sTRStatusApp && mapOldTR.get(tr.Id).Status__c != sTRStatusApp && tr.RecordTypeId == MEGAClass.ID_TRIAL_RT_STAND) ) {
							setSTR.add(tr.Id); 
						 }
				else 
					if (tr.Type__c == 'Free Trial' && tr.RecordTypeId == MEGAClass.ID_TRIAL_RT_STAND) {
						
						if (tr.Status__c == sTRStatusRej && mapOldTR.get(tr.Id).Status__c != sTRStatusRej) {
						
							If (tr.MEGAEnvironment__c != null) {
								setMega.add(tr.MEGAEnvironment__c);
								lstEnvId.add(tr.MEGAEnvironment__c);

								for (MEGAEnvironment__c Mega : [SELECT Id, Name, Free_Trial_Request_Closed__c, Status__c FROM MEGAEnvironment__c  WHERE Id IN: SetMega]) {
									Mega.Status__c = 'FREE';
									Mega.Free_Trial_Request_Closed__c = True;
									//WSRestCalloutClass.futuremakepostcall(lstEnvId);
									lstMega.add(Mega);
									System.debug('***MEGA environment after rejection ' + lstMega);
								}
							}
						}
						//*REF-2916 7-Apr-21 RCA To reassign Mega Env after resubmission
						else 
							if (tr.Status__c == sTRStatusSub && mapOldTR.get(tr.Id).Status__c == sTRStatusRej) {
								List<MEGAEnvironment__c> lstMega1 = new List<MEGAEnvironment__c>([SELECT Id, Name, Status__c, Version__c, Server__r.Name, Server__r.Version__r.Name , Server__r.Version__r.CreatedDate, Password__c FROM MEGAEnvironment__c 
																								  WHERE Status__c = 'FREE' AND Server__r.Status__c = 'UP' AND Server__r.Platform__c = 'Free Trial' order by Server__r.Version__r.Release_date__c DESC LIMIT 1]);					
								If (lstMega1.size() > 0) {
									TrialRequest__c TR1 = new TrialRequest__c (); 	
									TR1.id = tr.Id;
									TR1.MEGAEnvironment__c = lstMega1[0].Id;
									SetMega.add(lstMega1[0].Id); 
									ListTrial.add(TR1);
								}
								System.debug('***MEGA environment SetMega after resubmission ' + SetMega + tr.id);	

								for (MEGAEnvironment__c Mega : [SELECT Id, Name, Free_Trial_Request_Closed__c, Status__c FROM MEGAEnvironment__c  WHERE Id IN: SetMega]) {
									Mega.Status__c = 'BUSY';
									Mega.Free_Trial_Request_Closed__c = false;
									lstMega.add(Mega);
								}	
								System.debug('***MEGA environment lstMega after resubmission' + lstMega);	
								
								for (TrialLogin__c TRL1 : [SELECT Id, Password__c FROM TrialLogin__c  WHERE TrialRequest__c IN: setTR]) {
									TRL1.Password__c = lstMega1[0].Password__c;
									lstLoginChg.add(TRL1);
								}
								System.debug('***MEGA environment lstMega after resubmission' + lstMega);		

							}
			        }

            }

			/* RCA 2019-11-20 REF-1797 FREE TRIAL PROJECT BEGIN*/
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
				/* RCA 2019-11-20 REF-1797 FREE TRIAL PROJECT END*/
			}
			
			If (lstMega.size() > 0) {
					try {
						update lstMega;
					} 
					catch (system.Dmlexception e) {
						system.debug ('**Exception for Mega Environment after rejection or resubmission' + e);
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
				/* FOR TRIAL REQUEST WITH 'APPROVED' status AND "Training Trial" type HHI 070218 Removed on Training Team demand (Send Manually)
				if(setTTApprov != null && setTTApprov.size() > 0){
                    EmailTemplateClass.prepareBulkUpdate(UtilityClass.getTrialLogin(setTTApprov));
                }
				*/
				// FOR TRIAL REQUEST WITH 'APPROVED' status AND "Standard Trial" type
                if(setSTR != null && setSTR.size() > 0){
                    EmailTemplateClass.prepareBulkUpdate(UtilityClass.getTrialLogin(setSTR));
                }
				if(setTTRejec != null && setTTRejec.size() > 0){
					TrialRequestClass.deleteEventsFromTTR(setTTRejec);
				}
            }
            catch(Exception e){ lstNewTR[0].addError('Trigger afterUpdate on TrialRequest__c : Exception at line number = ' + e.getLineNumber() + ', Error message = ' + e.getMessage()); }
        }
    }
}