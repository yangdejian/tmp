local package={}
package.delivery = {}
package.up = {}
package.down = {}
package.warning = {}


package.delivery.recharge_status = {not_start = 10, waiting = 20, doing = 30, success = 0, failure = 90, noneed = 99}

package.delivery.notify_result = {success= 0,failure = 1}

package.get=function(obj, val)
  for i,v in pairs(obj) do
    if(tostring(v.val)==tostring(val)) then
      return v
    end
  end
  print("找不到对应的枚举package")
  return nil
end

return package
