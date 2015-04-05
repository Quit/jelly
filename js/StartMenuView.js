// Overload App.StonehearthStartMenuView._onMenuClick to fire an event if no menu entry was defined.
$(top).on('jelly_pre_rootview_init', function()
{
   App.StonehearthStartMenuView = App.StonehearthStartMenuView.extend({
      _onMenuClick: function(menuId, nodeData) {
         //radiant.keyboard.setFocus(this.$());
         var menuAction = this.menuActions[menuId];

         // do the menu action
         if (menuAction)
            menuAction();
         else
            $(top).trigger('jelly_startmenu_' + menuId);
      }
   });
})