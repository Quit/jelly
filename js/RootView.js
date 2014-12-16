// Overload App.RootView to add additional hooks
App.RootView = App.RootView.extend({
   init : function() {
         var self = this;
      
         $(top).trigger('jelly.PreRootViewInit');
         self._super();
         $(top).trigger('jelly.PostRootViewInit');
   }
});