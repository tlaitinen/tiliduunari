
/**
 * The main application class. An instance of this class is created by app.js when it calls
 * Ext.application(). This is the ideal place to handle application launch and initialization
 * details.
 */
Ext.define('Receipts.Application', {
    extend: 'Ext.app.Application',
    
    name: 'Receipts',
    requires: [
        'Ext.data.proxy.Rest', 
        'Ext.form.field.Checkbox',
        'Ext.grid.Panel',
        'Ext.grid.plugin.CellEditing'
    ],
    controllers: [
        'Login@Receipts.controller',
        'ReceiptTransferForm@Receipts.controller',
        'ReceiptPreview@Receipts.controller',
        'UnclassifiedReceiptsGrid@Receipts.controller'
    ],

    stores: [
    ],
    
    init:function() {
        moment.locale(__('locale'));
        Ext.History.init();
        Ext.define('Receipts.CustomReader', {
            extend: 'Ext.data.reader.Reader',
            alias: 'reader.customreader',
            read: function(xhr)  {
                return {success:  xhr.status == 200 };
            }
        }, function (customReader) {
            function maybeCreateDefaultUserGroup(form, record) {
                if (!record.get('defaultUserGroupId')) {
                    var ug = Ext.create('Receipts.model.UserGroup');
                    ug.set('name', record.get('name'));
                    ug.set('email', Receipts.GlobalState.user.defaultUserGroupEmail);
                    var dfd = jQuery.Deferred();
                    ug.save({
                        success: function (rec, op) {
                            try {
                                var r = JSON.parse(op.getResponse().responseText);
                                record.set('defaultUserGroupId', r.id);
                                dfd.resolve();;
                            } catch (e) {
                                console.log(e);
                            }
                        }
                    });
                    return dfd;
                } else {
                    return true;
                }
            }
            $.get("resources/backend.json").done(function(defs) {
                var config = {
                    name: 'Receipts',
                    urlBase: 'backend/db',
                    defaultStoreFilters: [
                        {
                            field:'hideDeleted',
                            value:"true"
                        }
                    ],
                    routes: {

                        processperiods: {
                            combo: {
                                forceSelection: true
                            }
                        },
                        receipts: {

                            autoSync:true,
                            grids: [
                                {
                                    widget: 'receiptsgrid',
                                    loadOnRender:true,
                                    title: undefined,
                                    preload:false,
                                    plugins: 'cellediting',
                                    columns: [ 
                                        { field:'name', editor: { allowBlank:false }, flex:5 }, 
                                        { 
                                            field:'amount', 
                                            editor: {
                                                xtype: 'numberfield'
                                            }, 
                                            flex:1,
                                            renderer: function(v) {
                                                return Ext.util.Format.currency(v, '€', 2, true);
                                            }

                                        },
                                        { 
                                            field:'processed', 
                                            renderer: function (value,meta, record) {
                                                if (record.get('processed') == true)
                                                    return '<span class="glyphicon glyphicon-ok"></span>';
                                                return ' ';
                                            }
                                        }
                                    ],
                                    bottomToolbar: [
                                        { name: 'remove', action:'remove' },
                                        { name: 'send', requireSelection:false}, 
                                        { name: 'transfer' }
                                    ]

                                },
                                {
                                    widget: 'unclassifiedreceiptsgrid',
                                    searchField:false,
                                    title: undefined,
                                    loadOnRender:true,
                                    preload:false,
                                    plugins: {
                                        ptype: 'cellediting',
                                        clicksToEdit: 1
                                    },
                                    filters: [
                                        {
                                            field:'processPeriodId',
                                            value:null,
                                            comparison:'is'
                                        }
                                    ],
                                    columns: [ 
                                        { field:'name', editor: { allowBlank:false }, flex:5 }, 
                                        { 
                                            field:'amount', 
                                            editor: {
                                                xtype: 'numberfield'
                                            }, 
                                            flex:1,
                                            renderer: function(v) {
                                                return Ext.util.Format.currency(v, '€', 2, true);
                                            }
                                        },
                                        {
                                            field:'processPeriodId',
                                            editor: {
                                                xtype: 'processperiodscombo'
                                            },
                                            flex:2
                                        }
                                    ],
                                    bottomToolbar: [
                                        { name: 'remove', action:'remove' }
                                    ]

                                }

                            ]
                        },
                        users: {
                            grids : [
                                {
                                    widget: 'usersgrid',
                                    columns: [ 'name', 'firstName', 'lastName' ],
                                    toolbar: [
                                        {
                                            xtype: 'usergroupscombo',
                                            filterField: 'userGroupId'
                                        }
                                    ],
                                    bottomToolbar: [ 
                                        { name: 'new', action:'new' },
                                        { name: 'remove', action:'remove' } 
                                    ], 
                                    form:'userform',
                                    formHeight:330
                                }
                            ],
                            forms: [
                                {
                                    widget: 'userform',
                                    labelWidth:200,
                                    items: [
                                        'name', 'firstName', 'lastName', 'email', 
                                        'timeZone',
                                        'strictEmailCheck',
                                        'defaultUserGroupId',
                                        { xtype:'button', name:'setUserPassword', 
                                         form:'userpasswordform', formHeight:200 }
                                    ],
                                    beforeSubmit: [maybeCreateDefaultUserGroup],
                                    success: [function(record) {
                                        ['usergroupsgrid', 'usergroupitemsgrid'].forEach(function (n) {
                                            Ext.ComponentQuery.query(n).forEach(function(g) { g.store.reload(); });
                                        });
                                    }]
                                },
                                {
                                    widget: 'userpasswordform',
                                    items: [
                                        { 
                                            name: 'password', 
                                            xtype:'textfield', 
                                            inputType: 'password',
                                            minLength:6,
                                            minLengthText: 'passwordMinLength'
                                        },
                                        {
                                            name: 'passwordAgain',
                                            xtype:'textfield',
                                            inputType: 'password'
                                        }
                                    ],
                                    validation:function (values) {
                                        if (values.password != values.passwordAgain) {
                                            return 'validationError.password';
                                        }
                                    },
                                    buttons: [
                                        {
                                            name: 'ok',
                                            action: 'saveandclose',
                                            url: 'backend/set-user-password/(ID)',
                                            updateRecord:false
                                        },
                                        'closewithoutsaving'
                                    ]
                                }
                            ]
                        },
                        usergroups: {
                            grids: [
                                {
                                    widget: 'usergroupsgrid',
                                    globalStore:true,
                                    columns: [ 'name' ], 
                                    form:'usergroupform',
                                    bottomToolbar: [ 
                                        { name: 'new', action:'new' },
                                        { name: 'remove', action:'remove' } 
                                    ],
                                    formHeight:200
                                }
                            ],
                            forms: [
                                {
                                    widget: 'usergroupform',
                                    items: [ 'name', 'email', 'createPeriods' ]
                                }
                            ]
                        },
                        usergroupitems: {
                            grids: [
                                {
                                    widget: 'usergroupitemsgrid',
                                    globalStore:true,
                                    searchField:false,
                                    columns: [
                                        { field: 'userName', flex:2 },
                                        { field: 'userGroupName', flex:2 },
                                        { field: 'mode', flex:1 }
                                    ],
                                    bottomToolbar: [
                                        { name:'remove', action:'remove' }
                                    ]

                                }
                            ]
                        },
                        usergroupcontents: {
                            grids: [
                                {
                                    searchField:false,
                                    widget:'usergroupcontentsgrid',
                                    columns: [ 'userGroupName' ],
                                    bottomToolbar: [
                                        { name:'remove', action:'remove' }
                                    ]
                                }
                            ]
                        }
                    }
                };
               var ydsl = yesodDsl(defs, __, config, function () { Receipts.GlobalState.fireEvent('ready'); });
           });
       });
   }
});
Ext.define('Receipts.GlobalState', {
    extend: 'Ext.util.Observable',
    singleton:true
});



