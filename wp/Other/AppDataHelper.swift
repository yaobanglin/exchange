
//
//  AppDataHelper.swift
//  wp
//
//  Created by 木柳 on 2017/1/18.
//  Copyright © 2017年 com.yundian. All rights reserved.
//

import UIKit
import SVProgressHUD
class AppDataHelper: NSObject {
    fileprivate static var helper = AppDataHelper()
    class func instance() -> AppDataHelper{
        return helper
    }
    
    private var productTimer: Timer?
    func initData() {
        //productTimer = Timer.scheduledTimer(timeInterval: 5 , target: self, selector: #selector(initProductData), userInfo: nil, repeats: true)
       // Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(initAllKlineChartData), userInfo: nil, repeats: true)
        initErrorCode()
        checkTokenLogin()
//        initProductData()
    }
    //请求商品数据 
    func initProductData() {
        if UserModel.share().token.length() <= 0{
            return
        }
        var allProducets: [ProductModel] = []
        AppAPIHelper.deal().products(pid: 0, complete: {[weak self](result) -> ()? in
            self?.productTimer?.invalidate()
            if let products: [ProductModel] = result as! [ProductModel]?{
                //拼接所有商品
                allProducets += products
                //商品分类
                self?.checkAllProductKinds(allProducts: allProducets)
                DealModel.share().allProduct = allProducets
                //默认选择商品
                if allProducets.count > 0{
                    DealModel.share().selectProduct = allProducets[0]
                }

            }else{
            }
            return nil
        }) {(error) -> ()? in
            SVProgressHUD.showErrorMessage(ErrorMessage: "商品数据获取失败，请稍候再试", ForDuration: 1.5, completion: nil)
            return nil
        }
    }
    

    //对所有商品进行分类
    func checkAllProductKinds(allProducts: [ProductModel]) {
        for product in allProducts {
            if DealModel.share().productKinds.count == 0 {
                DealModel.share().productKinds.append(product)
            }else{
                var isContent = false
                for kind in DealModel.share().productKinds{
                    if product.symbol == kind.symbol {
                        isContent = true
                    }
                }
                if isContent == false{
                    DealModel.share().productKinds.append(product)
                }
            }
        }
    }
    func moreChartData() {
        moreLineChartData()
        moreSelectKlineChartData()
    }
    //根据商品分时数据
    func initLineChartData(){
        for product in DealModel.share().productKinds {
            let now = Date.nowTimestemp()
            var last = KLineModel.maxTime(type: .miu, symbol:product.symbol)
            if last < Date.startTimestemp(){
                last = Date.startTimestemp()
            }
            let future = last + 60
            if future > now{
                return
            }
            let end = now - 60*AppConst.klineCount
            lineChartData(product: product, fromTime: now, endTime: end)
        }
    }
    func moreLineChartData(){
        if let product = DealModel.share().selectProduct{
            let zero = Date.startTimestemp()
            let min = KLineModel.minTime(type: .miu, symbol:product.symbol)
            let last = min - 300
            if last < zero{
                return
            }
            lineChartData(product: product, fromTime: min, endTime: zero)
        }
    }
    func lineChartData(product: ProductModel, fromTime: Double, endTime: Double){
        let param = KChartParam()
        param.symbol = product.symbol
        param.exchangeName = product.exchangeName
        param.platformName = product.platformName
        param.aType = 4
        param.startTime = Int64(fromTime)
//        param.endTime = Int64(endTime)
        AppAPIHelper.deal().timeline(param: param, complete: {(result) -> ()? in
            if let models: [KChartModel] = result as? [KChartModel]{
                KLineModel.cacheTimelineModels(models: models)
            }
            return nil
        }, error: { (error) ->()? in
            SVProgressHUD.showErrorMessage(ErrorMessage: error.description, ForDuration: 1, completion: nil)
            return nil
        })
    }
    
    //根据商品请求K线数据
    func initAllKlineChartData() {
        initLineChartData()
        initKLineChartData(type: .miu5)
        initKLineChartData(type: .miu15)
        initKLineChartData(type: .miu30)
        initKLineChartData(type: .miu60)
    }
    func initSelectKlineChartData() {
        let type = DealModel.share().klineTye
        initKLineChartData(type: type)
    }
    
    func initKLineChartData(type: KLineModel.KLineType) {
//        if type == .miu{
//            return
//        }
        for product in DealModel.share().productKinds{
            let now = Date.nowTimestemp()
            var last = KLineModel.maxTime(type: type, symbol:product.symbol)
            if last < Date.startTimestemp(){
                last = Date.startTimestemp()
            }
            let future = last + Double(type.rawValue)
            if future > now{
                return
            }
            let end = now - Double(type.rawValue)*AppConst.klineCount
            kLineChartData(type: type, product: product, fromTime: now, endTime: end)
        }
    }
    func moreSelectKlineChartData() {
        let type = DealModel.share().klineTye
        moreKLineChartData(type: type)
    }
    func moreKLineChartData(type: KLineModel.KLineType) {
        if type == .miu{
            return
        }
        for product in DealModel.share().productKinds {
            let zero = Date.startTimestemp()
            let min = KLineModel.minTime(type: type, symbol:product.symbol)
            let last = min - Double(type.rawValue*5)
            if last < zero{
                return
            }
            kLineChartData(type: type, product: product, fromTime: min, endTime: zero)
        }
    }
    func kLineChartData(type: KLineModel.KLineType, product: ProductModel, fromTime: Double, endTime: Double) {
        let param = KChartParam()
        param.symbol = product.symbol
        param.exchangeName = product.exchangeName
        param.platformName = product.platformName
        param.chartType = type.rawValue
        param.startTime = Int64(fromTime)
//        param.endTime = Int64(endTime)
        AppAPIHelper.deal().kChartsData(param: param, complete: { (result) -> ()? in
            if let chart: ChartModel = result as? ChartModel{
                KLineModel.cacheKChartModels(chart: chart)
            }
            return nil
        }, error:{ (error) ->()? in
//            SVProgressHUD.showErrorMessage(ErrorMessage: error.description, ForDuration: 1, completion: nil)
            return nil
        })
    }
    
    //验证token登录
    func checkTokenLogin() {
        
        //token是否存在
        if  UserDefaults.standard.value(forKey: SocketConst.Key.token) as? String != nil{
        
            let model = TokenModel()
            model.token = UserDefaults.standard.value(forKey: SocketConst.Key.token) as! String

            model.requestPath = "/api/user/refreshToken.json"
            HttpRequestManage.shared().postRequestModelWithJson(requestModel: model, reseponse: { (responseObject) in
                if let json = responseObject as? Dictionary<String, AnyObject> {
                    
                    UserDefaults.standard.setValue(json[SocketConst.Key.token], forKey: SocketConst.Key.token)
                    _ = UserDefaults.standard.synchronize()
                    self.getUserInfo()
                    
                     NotificationCenter.default.post(name: NSNotification.Name(rawValue: AppConst.NotifyDefine.UpdateUserInfo), object: nil)
                }
            }, failure: { (error) in
                UserDefaults.standard.set(nil, forKey: SocketConst.Key.token)
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: AppConst.NoticeKey.logoutNotice.rawValue), object: nil)
            })
      
        }

    }
    //清楚用户数据
    func clearUserInfo() {
        UserDefaults.standard.removeObject(forKey: SocketConst.Key.uid)
        UserDefaults.standard.removeObject(forKey: SocketConst.Key.token)
        UserModel.share().token = ""
        UserModel.share().currentUserId = 0
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: AppConst.NoticeKey.logoutNotice.rawValue), object: nil, userInfo: nil)
    }
    
    //获取错误信息
    func initErrorCode() {
        AppAPIHelper.commen().errorCode(complete: { (result) -> ()? in
            if let errorDic: NSDictionary = result as? NSDictionary{
                let path = Bundle.main.path(forResource: "errorcode.plist", ofType:nil)
                let success = errorDic.write(toFile: path!, atomically: true)
                print(success ? "错误码写入成功" : "错误码写入失败")
            }
            return nil
        }, error: nil)
    }
    //获取个人信息
    func getUserInfo()  {
        
        let info = GetUserInfo()
        info.token = UserDefaults.standard.object(forKey: SocketConst.Key.token) as! String
        HttpRequestManage.shared().postRequestModel(requestModel: info, responseClass: UserInfoVCModel.self, reseponse: { (result) in
            
        }) { (error) in
            
        }

    }
    //获取验证码
    func getVailCode(phone : String, type : Int  ,reseponse:@escaping reseponseBlock)  {
        let model : GetCodetype = GetCodetype()
        model.phoneNum = phone
        model.codeType = type
        model.requestPath = "/api/sms/code.json"

        HttpRequestManage.shared().postRequestModelWithJson(requestModel: model, reseponse: { (result) in
            reseponse(result)
        }) { (error) in
            
        }
    }

    
    
}
